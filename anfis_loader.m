anfis_model = py.load_model.load_full_model("checkpoint.pth");

anfis_model(py.torch.tensor([0.,0.,0.]).unsqueeze(int32(0)))