{ lib, pkgs, config, ... }:

with lib;

let
  cfg = config.programs.ai;
in
{
  options.programs.ai = {
    enable = mkEnableOption "AI support (Ollama, etc.)";
  };
  
  config = mkIf cfg.enable {
    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      loadModels = [ "llama3.2:3b" "deepseek-r1:1.5b"];
    };
  };
}
