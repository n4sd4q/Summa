# Security

Summa is a Wolfram Language package that contracts tensors. It runs only in your Mathematica session
and needs no account, no key and no server of its own.

## Network access

The package's only access to the network is a check for a newer release. Loaded in a notebook, it asks GitHub's API
(`https://api.github.com/repos/n4sd4q/Summa/releases/latest`) at most once a day, in the background, for the latest
release; if that release is newer than the one loaded, the banner shows the `PacletInstall` line of the new release. The
request carries nothing about you or your work (GitHub sees it as any web request, with the address it comes from). The
date of the last check is kept in `LastUpdateCheck.txt`, in the folder `ApplicationData/Summa` of `$UserBaseDirectory`.
A script never checks, nor does a session in which Mathematica may not use the Internet (`$AllowInternet` is `False`), and
every failure is silent.

To load the package without the check:

```mathematica
$SummaUpdateCheck = False;
Needs["Summa`"]
```

The first line in your `init.m` (`FileNameJoin[{$UserBaseDirectory, "Kernel", "init.m"}]`) turns it off for good;
`SummaUpdateCheck[]` checks by hand.

## Reporting a vulnerability

Please report a security problem privately, not in a public issue:
[*Report a vulnerability*](https://github.com/n4sd4q/Summa/security/advisories/new), on the security tab of the
repository (GitHub's private vulnerability reporting). Fixes go into the next release; only the latest release is
supported. Other problems are welcome as [issues](https://github.com/n4sd4q/Summa/issues).
