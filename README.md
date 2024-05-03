# Zathura-images
An image plugin for [zathura](ihttps://pwmt.org/projects/zathura/)

# Building
```zsh
git clone https://github.com/thrombe/zathura-images
cd zathura-images
zig build --release=fast
```

# Installation
### NixOS
```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.11";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";

    # ...
    # define flake input
    zathura-images = {
      url = "github:thrombe/zathura-images";
      inputs.nixpkgs.follows = "nixpkgs";
      # NOTE: The stable Nixpkgs version doesn't have the necessary Zathura update for zathura-images to work, so we need to rely on the unstable branch instead.
      inputs.nixpkgs-unstable.follows = "nixpkgs-unstable";
    };
  };

  # ...
  outputs = inputs: let
    system = "x86_64-linux";

    unstable = import inputs.nixpkgs-unstable {
      overlays = [
        inputs.zathura-images.overlays."${system}".default
      ];
      inherit system;
    };

    # then add zathura to your environment packages
    packages = [
      unstable.zathura
    ];

  # ...
}
```

### For Other Linux Distributions
Following the instructions in the [Zathura plugin development guide](https://github.com/pwmt/zathura-pdf-mupdf?tab=readme-ov-file#installation), once you've built the plugin, you'll need to move the file `./zig-out/lib/libzathura-images.so` to Zathura's plugin directory. By default, this directory is located at `/usr/lib/zathura`.

Alternatively, you can simplify access by setting up an alias in your `~/.zshrc` file:

```zsh
alias zathura-images="zathura -p /path/to/directory/with/the/lib/"
````

Then, copy the file `./zig-out/lib/libzathura-images.so` to the specified directory.

