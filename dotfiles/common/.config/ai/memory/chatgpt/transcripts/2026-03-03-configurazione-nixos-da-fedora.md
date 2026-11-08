---
conversation_id: "69a7607d-5e54-8394-ac56-e8fed40dcbcf"
title: "Configurazione NixOS da Fedora"
created: 2026-03-03
updated: 2026-03-03
model: "gpt-5-2"
messages: 2
---

# Configurazione NixOS da Fedora

## Utente — 2026-03-03 23:28

Mi piacerebbe provare NixOS come sistema operativo mi puoi fare una configurazione per Nix partendo da questo Ansible playbook che è stato scritto per Fedora.
https://github.com/fscotto/fedora-playbook

## ChatGPT — 2026-03-03 23:29

Ok — ti preparo una base **NixOS (flake)** che ricalca *il tuo* `fedora-playbook` (storage Btrfs+Snapper+grub-btrfs, security baseline, pacchetti “workstation”, Flatpak+Flathub, YubiKey/pcscd/udev, dotfiles+stow, fonts). Mi baso sui contenuti del repo che hai linkato. citeturn2view0turn7view1turn6view4turn11view4turn12view0

Sotto trovi una struttura pronta da copiare in una cartella tipo `nixos/` e poi adattare (username, UUID dei filesystem, device LUKS, ecc.).

---

## Struttura consigliata

```text
nixos/
  flake.nix
  hosts/
    deadalus/
      configuration.nix
      hardware-configuration.nix   # generato da nixos-generate-config
  home/
    fscotto.nix
```

---

## `flake.nix`

```nix
{
  description = "NixOS workstation (porting da fedora-playbook)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    home-manager = {
      url = "github:nix-community/home-manager/release-24.11";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, ... }:
  let
    system = "x86_64-linux";
  in {
    nixosConfigurations.deadalus = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        ./hosts/deadalus/hardware-configuration.nix
        ./hosts/deadalus/configuration.nix

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          # cambia "fscotto" se il tuo utente è diverso
          home-manager.users.fscotto = import ./home/fscotto.nix;
        }
      ];
    };
  };
}
```

---

## `hosts/deadalus/configuration.nix`

> Qui ho portato **i blocchi principali** del playbook:
> - Flatpak+Flathub + app (Chrome/Telegram/Spotify/Postman/DevPod) citeturn7view1turn10view4  
> - Snapper policy + grub-btrfs (quando disponibile) citeturn6view4  
> - sysctl hardening + session timeout + sudo hardening + firewall + auto-upgrade citeturn7view0turn11view0turn11view4  
> - YubiKey packages + pcscd + udev rule citeturn12view0  
> - “workstation packages” equivalenti alla lista DNF (bat/fzf/ripgrep/… ecc.) citeturn7view0turn6view0  

```nix
{ config, pkgs, lib, ... }:

let
  user = "fscotto"; # <--- cambia se serve
in
{
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "Europe/Rome";
  i18n.defaultLocale = "it_IT.UTF-8";

  networking.hostName = "deadalus";
  networking.networkmanager.enable = true;

  # Firewall (Fedora playbook: firewalld ON) -> NixOS firewall ON
  networking.firewall.enable = true;

  # Audio / desktop basics
  services.dbus.enable = true;

  # Display manager + XFCE (il tuo playbook è per Fedora XFCE spin)
  services.xserver.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  services.xserver.displayManager.lightdm.enable = true;

  # Utente
  users.users.${user} = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "audio"
      "video"
      "libvirtd"
      "docker"
    ];
  };

  # Sudo hardening (timestamp_timeout/logfile) come nel playbook
  security.sudo.enable = true;
  security.sudo.extraConfig = ''
    Defaults timestamp_timeout=5
    Defaults passwd_timeout=1
    Defaults logfile="/var/log/sudo.log"
  '';

  # Session timeout shell (TMOUT) come /etc/profile.d/99-session-timeout.sh citeturn11view4
  environment.etc."profile.d/99-session-timeout.sh".text = ''
    # Managed by NixOS: workstation session timeout
    TMOUT=1800
    export TMOUT
    readonly TMOUT
  '';

  # sysctl hardening (porta pari-pari della lista playbook.yml) citeturn7view0turn11view0
  boot.kernel.sysctl = {
    "kernel.randomize_va_space" = 2;
    "kernel.kptr_restrict" = 2;
    "kernel.dmesg_restrict" = 1;
    "kernel.yama.ptrace_scope" = 1;
    "fs.suid_dumpable" = 0;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
  };

  # Disable core dumps (equivalente al limits.d del playbook)
  systemd.coredump.enable = false;

  # Auto-upgrade (equivalente a dnf-automatic.timer) citeturn11view2
  system.autoUpgrade = {
    enable = true;
    dates = "daily";
    randomizedDelaySec = "0";
    flake = "/etc/nixos"; # oppure path dove tieni il repo
  };

  # Virtualizzazione (nel playbook ci sono qemu tools e btrfs subvol @libvirt) citeturn7view0turn6view4
  virtualisation.libvirtd.enable = true;
  programs.virt-manager.enable = true;

  # Container tooling (nel playbook: podman) citeturn7view0
  virtualisation.podman.enable = true;
  virtualisation.podman.dockerCompat = true;

  # Flatpak + Flathub + app list (Chrome/Telegram/Spotify/Postman/DevPod) citeturn10view4turn7view0
  services.flatpak.enable = true;

  systemd.services.flatpak-setup = {
    description = "Flatpak: add flathub + install base apps (playbook parity)";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "flatpak.service" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = [ pkgs.flatpak ];
    script = ''
      set -euo pipefail
      flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

      # Installa le app del tuo playbook
      for app in \
        com.google.Chrome \
        org.telegram.desktop \
        com.spotify.Client \
        com.getpostman.Postman \
        sh.loft.devpod
      do
        flatpak install -y flathub "$app" || true
      done
    '';
  };

  # YubiKey + smartcard (pcscd + udev rules) citeturn12view0turn6view3
  services.pcscd.enable = true;
  services.udev.extraRules = ''
    # YubiKey FIDO/U2F access (da fedora-playbook)
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", MODE="0660", TAG+="uaccess"
    ACTION=="add|change", SUBSYSTEM=="usb", ATTR{idVendor}=="1050", MODE="0660", TAG+="uaccess"
  '';

  # PAM U2F (parte “PAM enrollment” nel playbook: la config fine dipende dal tuo flusso)
  security.pam.u2f.enable = true;

  # NOTE: LUKS2 + FIDO2 unlock “al boot” (nel playbook è condizionale e fa enrollment)
  # Su NixOS si fa via systemd-cryptenroll + crypttab options.
  # Ti lascio un blocco commentato da completare con il tuo device:
  #
  # boot.initrd.luks.devices."cryptroot" = {
  #   device = "/dev/disk/by-uuid/XXXX-XXXX";
  #   preLVM = true;
  #   crypttabExtraOpts = [ "fido2-device=auto" "token-timeout=10" ];
  # };

  # Pacchetti “workstation” (mapping 1:1 concettuale dalle liste DNF) citeturn7view0turn6view0
  environment.systemPackages = with pkgs; [
    # base + cli
    btrfs-progs ca-certificates curl wget git gnupg gnumake gcc clang clang-tools
    bat fzf ripgrep jq tmux entr rsync rclone tealdeer unzip
    strace ltrace gdb valgrind
    neovim
    yt-dlp
    pinentry pinentry-gnome3
    nodejs
    go
    python3 python3Packages.pip virtualenv pipx
    # office / utils
    libreoffice thunderbird
    flameshot
    poppler_utils
    # qemu bits
    qemu_kvm
    # “optional_cli_packages” analoghi
    delta fastfetch fd papirus-icon-theme
    # yubikey toolchain
    yubikey-manager yubikey-personalization fido2-tools opensc pcsclite_ccid
    # stow + mise (il playbook usa stow e installa mise via curl|sh) citeturn10view0turn6view2
    stow
    mise
  ];

  # Fonts base (Liberation) + Nerd Fonts (sostituisce download manuale zip) citeturn10view0
  fonts.packages = with pkgs; [
    liberation_ttf
    (nerdfonts.override { fonts = [ "FiraCode" "JetBrainsMono" "Iosevka" "UbuntuMono" "Ubuntu" "0xProto" ]; })
  ];

  # Snapper (root) + timers (timeline/cleanup) citeturn6view4
  services.snapper = {
    snapshotInterval = "hourly";
    cleanupInterval = "daily";
    configs.root = {
      SUBVOLUME = "/";
      TIMELINE_CREATE = "yes";
      TIMELINE_CLEANUP = "yes";
      NUMBER_CLEANUP = "yes";
      NUMBER_LIMIT = "10";
      NUMBER_LIMIT_IMPORTANT = "5";
      TIMELINE_LIMIT_HOURLY = "8";
      TIMELINE_LIMIT_DAILY = "7";
      TIMELINE_LIMIT_WEEKLY = "4";
      TIMELINE_LIMIT_MONTHLY = "3";
      TIMELINE_LIMIT_YEARLY = "0";
    };
  };

  # grub-btrfs (integrazione snapshot menu) — modulo può variare per versione nixpkgs.
  # Se non esiste il servizio nel tuo channel, basta tenere il pacchetto e creare unit custom.
  environment.systemPackages = with pkgs; config.environment.systemPackages ++ [ grub-btrfs ];

  # Bootloader (placeholder)
  boot.loader.systemd-boot.enable = false;
  boot.loader.grub.enable = true;
  boot.loader.grub.efiSupport = true;
  boot.loader.grub.device = "nodev";
  boot.loader.efi.canTouchEfiVariables = true;

  system.stateVersion = "24.11";
}
```

---

## `home/fscotto.nix` (Home Manager)

Qui porto:
- attivazione `mise` in shell (nel playbook aggiunge riga in `.bashrc`) citeturn6view2  
- clone dotfiles + `stow --restow ...` (nel playbook) citeturn10view0turn7view0  

```nix
{ config, pkgs, lib, ... }:

let
  dotfilesRepo = "https://github.com/fscotto/dotfiles";
  dotfilesDir  = "${config.home.homeDirectory}/.dotfiles";
  stowPkgs = [ "bash" "starship" "emacs" "git" "fastfetch" "flameshot" "tmux" "bat" ];
in
{
  home.username = "fscotto";
  home.homeDirectory = "/home/fscotto";

  programs.bash.enable = true;

  # Mise activation (equivalente a eval "$(mise activate bash)")
  programs.bash.initExtra = ''
    if command -v mise >/dev/null 2>&1; then
      eval "$(mise activate bash)"
    fi
  '';

  # Git disponibile lato user (comodo per dotfiles)
  programs.git.enable = true;

  # Clone dotfiles + stow (one-shot ad ogni switch; idempotente “abbastanza”)
  home.activation.dotfiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    set -euo pipefail

    if [ ! -d "${dotfilesDir}/.git" ]; then
      ${pkgs.git}/bin/git clone "${dotfilesRepo}" "${dotfilesDir}"
    else
      ${pkgs.git}/bin/git -C "${dotfilesDir}" pull --ff-only || true
    fi

    cd "${dotfilesDir}"
    for p in ${lib.concatStringsSep " " stowPkgs}; do
      ${pkgs.stow}/bin/stow --restow "$p" || true
    done
  '';

  home.stateVersion = "24.11";
}
```

---

## Btrfs layout: cosa resta “manuale” (ma dichiarabile nei mount)

Nel playbook crei subvolumi `@log`, `@cache`, `@snapshots`, `@libvirt` e li monti su `/var/log`, `/var/cache`, `/.snapshots`, `/var/lib/libvirt`. citeturn2view0turn7view0turn6view4

Su NixOS:
- **la creazione** dei subvolumi la fai tipicamente **in fase di installazione** (o a mano una volta),
- poi in `hardware-configuration.nix` / `configuration.nix` metti i `fileSystems` con `options = [ "subvol=@log" ... ]`.

Esempio (da incollare *dopo* aver creato i subvolumi e sostituito UUID):

```nix
fileSystems."/" = {
  device = "/dev/disk/by-uuid/XXXX";
  fsType = "btrfs";
  options = [ "subvol=@"
              "compress=zstd"
              "noatime"
            ];
};

fileSystems."/var/log" = {
  device = "/dev/disk/by-uuid/XXXX";
  fsType = "btrfs";
  options = [ "subvol=@log" "compress=zstd" "noatime" ];
};

fileSystems."/var/cache" = {
  device = "/dev/disk/by-uuid/XXXX";
  fsType = "btrfs";
  options = [ "subvol=@cache" "compress=zstd" "noatime" ];
};

fileSystems."/.snapshots" = {
  device = "/dev/disk/by-uuid/XXXX";
  fsType = "btrfs";
  options = [ "subvol=@snapshots" "compress=zstd" "noatime" ];
};

fileSystems."/var/lib/libvirt" = {
  device = "/dev/disk/by-uuid/XXXX";
  fsType = "btrfs";
  options = [ "subvol=@libvirt" "compress=zstd" "noatime" ];
};
```

---

## Note rapide “porting” (cosa ho scelto)

- **Flatpak**: ho mantenuto lo stesso meccanismo (Flathub + install app) perché nel playbook è “source of truth” per Chrome/Telegram/Spotify/Postman/DevPod. citeturn7view0turn10view4  
- **Mise**: invece di `curl|sh`, su NixOS lo installo da `pkgs.mise` e lo attivo in shell via Home Manager. citeturn6view2  
- **Fonts Nerd Fonts**: invece di scaricare zip dalla “latest release”, su NixOS uso `nerdfonts.override { ... }` (più riproducibile). citeturn10view0  
- **YubiKey LUKS2 enroll**: nel playbook fai enrollment “live” e patch di PAM/cryptsetup (condizionale su device collegato). Su NixOS la parte “enroll” resta un comando (`systemd-cryptenroll`) mentre la *dichiarazione* sta in `boot.initrd.luks.devices.*`. citeturn6view3turn12view0  

---

Se vuoi, nel prossimo giro posso anche:
- estrarti **una lista di mapping puntuale** “DNF package → nixpkgs attribute” (con quelli che non esistono/che cambiano nome), partendo dalla tua lista `cli_packages`/`optional_cli_packages`. citeturn7view0turn6view0
