import torch
import datetime
from consequent_layer import ConsequentLayerType

def load_full_model(location):
    x_joint_definitons = [
        ('distance', JointTrapMembershipV2(*output[0], constant_center=True)),
        ('theta_far', JointTrapMembershipV2(*output[1], constant_center=True)),
        ('theta_near', JointTrapMembershipV2(*output[2], constant_center=True))
    ]

    outputs = ['angular_velocity']

    mambani = JointSymmetricTriangleMembership(0, 0.5, 0.25, 0.25, False, x_joint_definitons[0][1].required_dtype())

    model = make_joint_anfis(x_joint_definitons, outputs, rules_type=ConsequentLayerType.MAMDANI, mamdani_defs=mambani)

    load_anfis(model, location)

    return model