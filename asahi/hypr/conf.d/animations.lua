hl.config({
  animations = {
    enabled = true,
  },
})

hl.curve("ilyaEase", {
  type = "bezier",
  points = { { 0.05, 0.9 }, { 0.1, 1.05 } },
})

hl.animation({ leaf = "windows", enabled = true, speed = 5, bezier = "ilyaEase", style = "popin 80%" })
hl.animation({ leaf = "layers", enabled = true, speed = 5, bezier = "ilyaEase", style = "fade" })
hl.animation({ leaf = "fade", enabled = true, speed = 5, bezier = "ilyaEase" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 5, bezier = "ilyaEase", style = "slide" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 5, bezier = "ilyaEase", style = "fade" })
