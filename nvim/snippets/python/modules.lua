---@diagnostic disable: undefined-global
require("luasnip.loaders.from_lua").lazy_load()

return {
  parse("plt", "import matplotlib.pyplot as plt"),
  parse("np", "import numpy as np"),
  parse("pd", "import pandas as pd"),
  parse("jnp", "import jax.numpy as jnp"),
  parse("fnn", "import flax.linen as nn"),
  parse("tnn", "import torch.nn as nn"),
  parse("tF", "import torch.nn.functional as F"),
  parse({ trig = "ipdb", name = "ipdb breakpoint" }, "import ipdb; ipdb.set_trace()"),
}
