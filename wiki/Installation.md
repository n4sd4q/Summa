## Installing

Summa needs Mathematica 12.1 or later and nothing else. Install the paclet of the latest
[release](https://github.com/n4sd4q/Summa/releases) once:

<!-- not run -->
```mathematica
PacletInstall["https://github.com/n4sd4q/Summa/releases/download/v1.0.0/Summa-1.0.0.paclet"]
```

Without a connection, download the `.paclet` file from the release page and give `PacletInstall` its path.

## Loading

In every session:

```mathematica
Needs["Summa`"];
$SummaVersion
```

```text
1.0.0
```

In a notebook, loading prints a banner with the version, the license and the links; a script loads the package
silently. ``?Summa`*`` lists the functions and `?Einsum` explains one.

The guided tour, a notebook to run cell by cell, comes with the paclet:

<!-- not run -->
```mathematica
NotebookOpen[PacletObject["Summa"]["AssetLocation", "Examples"]]
```

## From a clone of the repository

To use a clone instead of the installed paclet (to try the latest changes, or to change the package), load the inner
folder `Summa/`, which holds `PacletInfo.wl`:

<!-- not run -->
```mathematica
PacletDirectoryLoad["/path/to/Summa/Summa"];
Needs["Summa`"]
```

The guided tour is `Examples.wl` at the top of the clone; it loads the paclet next to it, and runs as a script too:
`wolfram -script Examples.wl`.

## Updating

In a notebook the package looks for a newer release on GitHub at most once a day, in the background, and the banner then
shows the line that installs it; any failure is silent, and scripts never look. `SummaUpdateCheck[]` asks by hand:

<!-- not run -->
```mathematica
SummaUpdateCheck[]
```

It gives the version loaded, the latest release and the line that installs it (the keys `"InstalledVersion"`,
`"LatestVersion"` and `"InstallLine"`), and prints that line when the release is newer; without an answer from GitHub it
gives `$Failed` and the message `SummaUpdateCheck::latest`. To load without the check, set the variable before `Needs`
(in `init.m`, to turn it off for good):

<!-- not run -->
```mathematica
$SummaUpdateCheck = False;
Needs["Summa`"]
```

[`SECURITY.md`](https://github.com/n4sd4q/Summa/blob/main/SECURITY.md) says what the check sends. Installing a newer
release replaces the older one; `PacletUninstall["Summa"]` removes the package.

## When loading fails

- `Needs::nocont` or "cannot open": the paclet is not installed, or not found. `PacletFind["Summa"]` lists what
  Mathematica sees; install again, or load the clone with `PacletDirectoryLoad` (the inner folder `Summa/`).
- An older version loads: `PacletFind["Summa"]` lists more than one; `PacletUninstall` the older ones.
- Shadowing messages (`Einsum::shdw`): a function of the package was used before loading it, and a symbol of the same
  name was made in ``Global` ``. Restart the kernel, then load the package first.