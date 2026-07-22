{
  description = "NixOS configuration for Maibenben x525 and ThinkPad X1 Carbon Gen 13";

  inputs = {
    # Core inputs - version managed through lib/default.nix concept
    # Using nixos-unstable as the primary channel for latest features
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Secondary stable channel. Access in modules via `pkgs-stable.<name>`
    # for packages that are churny/broken on unstable.
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Home manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Disk management
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Theming
    stylix.url = "github:danth/stylix";
    
    # Development tools
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    # Applications
    firefox.url = "github:nix-community/flake-firefox-nightly";
    
    ayugram-desktop = {
      type = "git";
      submodules = true;
      url = "https://github.com/ndfined-crp/ayugram-desktop/";
    };
    
    v2rayb.url = "github:keepinfov/v2rayB/fix/md3-ui-improvements";
    
    winapps = {
      url = "github:winapps-org/winapps";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, stylix, v2rayb, winapps, ... }@inputs:
    let
      system = "x86_64-linux";

      # Import central configuration (named 'conf' to avoid shadowing NixOS config)
      conf = import ./lib {
        lib = nixpkgs.lib;
        root = ./.;
      };

      # Stable package set, available to all modules/home-manager as `pkgs-stable`.
      pkgs-stable = import inputs.nixpkgs-stable {
        inherit system;
        config.allowUnfree = true;
      };

      # Common special args for all hosts
      specialArgs = {
        inherit inputs conf pkgs-stable;
      };
      
      # Helper function to create a NixOS system
      mkHost = hostname: nixpkgs.lib.nixosSystem {
        inherit system specialArgs;
        modules = [
          # Core modules
          ./modules/core
          
          # Host-specific configuration
          ./hosts/${hostname}
          
          # External modules
          home-manager.nixosModules.home-manager
          disko.nixosModules.disko
          stylix.nixosModules.stylix
          v2rayb.nixosModules.default
          
          # Common home-manager settings
          {
            home-manager = {
              useGlobalPkgs = true;
              useUserPackages = true;
              backupFileExtension = "bak";
              extraSpecialArgs = specialArgs;
            };
          }
        ];
      };
    in
    {
      nixosConfigurations = {
        maibenben = mkHost "maibenben";
        carbon = mkHost "carbon";
      };
      
      # Development shells for different tasks
      devShells.${system} = import ./devshells {
        pkgs = import nixpkgs {
          inherit system;
          config.allowUnfree = true;
          overlays = [ inputs.rust-overlay.overlays.default ];
        };
        inherit inputs;
      };
    };
}
