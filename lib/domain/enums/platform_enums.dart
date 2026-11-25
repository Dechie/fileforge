/// The current target platform.
enum AppPlatform { linux, android }

/// Linux distribution family for dependency management.
enum DistroFamily {
  debian('Debian', 'apt'),
  fedora('Fedora/RHEL', 'dnf'),
  arch('Arch', 'pacman'),
  suse('SUSE', 'zypper'),
  unknown('Unknown', 'unknown');

  final String displayName;
  final String packageManager;
  const DistroFamily(this.displayName, this.packageManager);
}

/// CPU architectures the app recognizes.
enum CpuArchitecture {
  x86_64('x86_64'),
  aarch64('aarch64'),
  i386('i386'),
  unknown('unknown');

  final String name;
  const CpuArchitecture(this.name);

  static CpuArchitecture fromString(String arch) {
    switch (arch.toLowerCase()) {
      case 'x86_64':
      case 'amd64':
        return x86_64;
      case 'aarch64':
      case 'arm64':
        return aarch64;
      case 'i386':
      case 'i686':
        return i386;
      default:
        return unknown;
    }
  }
}

/// How the application is packaged/running.
enum RuntimeEnvironment { native, appImage, flatpak, snap, unknown }

/// Installation state of a dependency.
enum DependencyStatus {
  installed('Installed'),
  missing('Missing'),
  incompatibleVersion('Incompatible Version'),
  partiallyAvailable('Partially Available'),
  checking('Checking…');

  final String displayName;
  const DependencyStatus(this.displayName);

  bool get isUsable => this == installed || this == partiallyAvailable;
}
