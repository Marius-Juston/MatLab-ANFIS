#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
    ANFIS in torch: the ANFIS layers
    @author: James Power <james.power@mu.ie> Apr 12 18:13:10 2019
    Acknowledgement: twmeggs' implementation of ANFIS in Python was very
    useful in understanding how the ANFIS structures could be interpreted:
        https://github.com/twmeggs/anfis
"""

from collections import OrderedDict

import numpy as np
import torch
import torch.nn.functional as F

from antecedent_layer import AntecedentLayer, MamdaniAntecedentLayer
from consequent_layer import ConsequentLayer, SymmetricWeightsConsequentLayer, ConsequentLayerType, \
    PlainConsequentLayer, MamdaniConsequentLayer
from fuzzy_layer import JointFuzzifyLayer

dtype = torch.float


class WeightedSumLayer(torch.nn.Module):
    """
        Sum the TSK for each outvar over rules, weighted by fire strengths.
        This could/should be layer 5 of the Anfis net.
        I don't actually use this class, since it's just one line of code.
    """

    def __init__(self):
        super(WeightedSumLayer, self).__init__()

    def forward(self, weights, tsk):
        """
            weights.shape: n_cases * n_rules
                tsk.shape: n_cases * n_out * n_rules
             y_pred.shape: n_cases * n_out
        """
        # Add a dimension to weights to get the bmm to work:
        y_pred = torch.bmm(tsk, weights.unsqueeze(2))
        return y_pred.squeeze(2)


class ProductSum(torch.nn.Module):
    def forward(self, weights, tsk):
        return torch.matmul(weights, tsk)


class Empty(torch.nn.Module):
    def forward(self, *params):
        pass


class Normalization(torch.nn.Module):
    def forward(self, weights):
        return F.normalize(weights, p=1, dim=1)


class JointAnfisNet(torch.nn.Module):
    """
        This is a container for the 5 layers of the ANFIS net.
        The forward pass maps inputs to outputs based on current settings,
        and then fit_coeff will adjust the TSK coeff using LSE.
    """

    def __init__(self, description, invardefs, outvarnames, rules_type=ConsequentLayerType.HYBRID,
                 mamdani_ruleset=None,
                 mamdani_defs=None):
        super(JointAnfisNet, self).__init__()
        self.description = description
        self.outvarnames = outvarnames
        self.rules_type = rules_type
        varnames = [v for v, _ in invardefs]
        # mfdefs = [JointBellMembership(*mfs) for _, mfs in invardefs]
        mfdefs = [mfs for _, mfs in invardefs]
        self.num_in = len(invardefs)
        self.num_rules = np.prod([mfs.num_mfs for mfs in mfdefs])

        self.dtype = mfdefs[0].required_dtype()

        print("Using datatype:", self.dtype)

        if self.rules_type == ConsequentLayerType.MAMDANI:
            if mamdani_defs is None:
                raise ValueError("There is no Mamdani defintion")

            rules = MamdaniAntecedentLayer(mamdani_ruleset)
            normalization = Normalization()
            cl = MamdaniConsequentLayer(mamdani_defs, rules.mamdani_ruleset['outputs_membership'])
            output = ProductSum()
        else:
            rules = AntecedentLayer(mfdefs)
            normalization = Normalization()
            output = WeightedSumLayer()

            if self.rules_type == ConsequentLayerType.HYBRID:
                cl = ConsequentLayer(self.num_in, self.num_rules, self.num_out, dtype=self.dtype)
            elif self.rules_type == ConsequentLayerType.SYMMETRIC:
                cl = SymmetricWeightsConsequentLayer(self.num_in, self.num_rules, self.num_out, self.dtype)
            else:
                cl = PlainConsequentLayer(self.num_in, self.num_rules, self.num_out, self.dtype)

        self.layer = torch.nn.ModuleDict(OrderedDict([
            ('fuzzify', JointFuzzifyLayer(mfdefs, varnames)),
            ('rules', rules),
            ('normalize', normalization),
            ('consequent', cl),
            ('output', output),
            # weighted-sum layer is just implemented as a function.
        ]))

    @property
    def num_out(self):
        return len(self.outvarnames)

    @property
    def coeff(self):
        return self.layer['consequent'].coeff

    @coeff.setter
    def coeff(self, new_coeff):
        self.layer['consequent'].coeff = new_coeff

    def fit_coeff(self, *params):
        """
            Do a forward pass (to get weights), then fit to y_actual.
            Does nothing for a non-hybrid ANFIS, so we have same interface.
        """
        if self.rules_type == ConsequentLayerType.HYBRID:
            x, y_actual = params
            self(x)
            self.layer['consequent'].fit_coeff(x, self.weights, y_actual)
        elif self.rules_type == ConsequentLayerType.SYMMETRIC:
            # with torch.no_grad():
            mask, update = self.layer['consequent'].fit_coeff()

            # print("Coeff:", self.layer['consequent'].coeff.shape)

            if update:
                # print("Update")
                symmetrical_mask = torch.cat([mask, torch.flip(mask, dims=[0])[1:]])

                self.layer['rules'].mf_indices = self.layer['rules'].mf_indices[symmetrical_mask]

                # print("Rules", self.layer['rules'].mf_indices.shape)

    def input_variables(self):
        """
            Return an iterator over this system's input variables.
            Yields tuples of the form (var-name, FuzzifyVariable-object)
        """
        return self.layer['fuzzify'].varmfs.items()

    def output_variables(self):
        """
            Return an list of the names of the system's output variables.
        """
        return self.outvarnames

    def extra_repr(self):
        if self.rules_type == ConsequentLayerType.MAMDANI:
            vardefs = self.layer['fuzzify'].varmfs
            vardefs_names = list(vardefs.keys())

            rules = self.layer['rules'].mamdani_ruleset

            var_index = rules['variable_rule_index']
            mem_index = rules['membership_indices']
            out_index = rules['outputs_membership']

            out_name = self.layer['consequent'].mamdani_defs.names

            rules = []
            for i in range(len(var_index)):
                temp = []

                for var, mem in zip(var_index[i], mem_index[i]):
                    name = vardefs_names[var]

                    temp.append(f"{name} is {list(vardefs[name].mfdefs.keys())[mem]}")

                rules.append(f'Rule {i}: IF {" AND ".join(temp)} THEN {out_name[out_index[i][0]]}')
            return '\n'.join(rules)
        else:
            rstr = []
            vardefs = self.layer['fuzzify'].varmfs
            rule_ants = self.layer['rules'].extra_repr(vardefs).split('\n')
            for i, crow in enumerate(self.layer['consequent'].coeff):
                rstr.append('Rule {:2d}: IF {}'.format(i, rule_ants[i]))
                rstr.append(' ' * 9 + 'THEN {}'.format(crow.tolist()))
            return '\n'.join(rstr)

    def forward(self, x):
        """
            Forward pass: run x thru the five layers and return the y values.
            I save the outputs from each layer to an instance variable,
            as this might be useful for comprehension/debugging.
        """
        self.fuzzified = self.layer['fuzzify'](x)
        self.raw_weights = self.layer['rules'](self.fuzzified)
        self.weights = self.layer['normalize'](self.raw_weights)
        self.rule_tsk = self.layer['consequent'](x)
        self.y_pred = self.layer['output'](self.weights, self.rule_tsk)
        # y_pred = torch.bmm(self.rule_tsk, self.weights.unsqueeze(2))
        # self.y_pred = y_pred.squeeze(2)
        return self.y_pred


# These hooks are handy for debugging:

def module_hook(label):
    """ Use this module hook like this:
        m = AnfisNet()
        m.layer.fuzzify.register_backward_hook(module_hook('fuzzify'))
        m.layer.consequent.register_backward_hook(modul_hook('consequent'))
    """
    return (lambda module, grad_input, grad_output:
            print('BP for module', label,
                  'with out grad:', grad_output,
                  'and in grad:', grad_input))


def tensor_hook(label):
    """
        If you want something more fine-graned, attach this to a tensor.
    """
    return (lambda grad:
            print('BP for', label, 'with grad:', grad))