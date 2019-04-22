## Contributor requirements

### Developer Certiticate of Origin

This project uses the Developer Certificate of Origin, Version 1.1 used by Linux Foundation in developing the Linux Kernel. The Developer Certificate of Origin is in the root of this repository as [DCO.md][DCO], or online at [http://developercertificate.org/][DC]. In short, it says that you know where your contribution came from, you know you have the right to distribute it under the same license as this project, and that you can, and do, grant the right for this project to distribute it under the license listed in the [LICENSE.md][LMD] file of this project. You, as a contributor will say that you agree to the [DCO][DCO] by inluding a "Signed-off-by" line with any commit you make. The Command Line version of `git` makes doing so simple, use the `--signoff` or `-s` option when you do make your commit. Inside the commit message it will look like this:

    Signed-off-by: Ronald Lamoreaux <gitkey@chindraba.work>

### GPG-signed commits

In addition, to be acceptable to the project, the commits need to be GPG-signed. Again, `git` makes this simple with the `--gpg-sign[<keyid>]` or `-S[<keyid>]` options for a commit. That, of course, means that you will have to have a PGP key for the same name and email address as you use for creating the commits. GitHub has a good page, [Generating a new GPG key][GPG-help], that helps you do make one, and associate it with your GitHub account if you wish.

### OpenPGP public key

One extra step that is required beyond the GitHub help example is that your key also needs to be on a public key server somewhere. Two choices, that I know of, are the regular public key server network and [Keybase][kio]. The public key server pool can be accessed directly by [GNU Privacy Guard][gpg], the `gpg` command line tool, or on the web at many addresses, including a host at MIT, [https://pgp.mit.edu][mit-host]. The [Keybase app][app] supposedly makes things easier to use, and increases other users confidence in the connection between an identity and the key. However it is done, I support and encourage the personal and professional use of encryption in every possible case. Requiring contributors here to have, and use, an OpenPGP key is just one way to advance the cause.

---

## Code of Conduct

This project adheres to No Code of Conduct.  We are all adults.  Anyone's contributions will be considered.  Nothing else matters.

For more information please visit the [No Code of Conduct](https://github.com/domgetter/NCoC) homepage.

---

## Issues and bugs

### Find one, report one

If you find a bug, or have an issue with how something works, or doesn't work, open an [Issue][issue] on the GitHub project page. Maybe it is not a bug, or is the result of a prior decision, maybe it is a problem and needs to be fixed. Either way, the Issue will be seen and addressed.

### Find one, patch one

If you find a truly serious bug, and know how to fix it, code the solution and create a [Pull request][pull].
Kudos to anyone willing to take the time to create solutions rather than notices. Please read the __Contributor requirements__ secion above.

---

## Feature requests and enhancements

Treat these like an issue you found. The project is small enough that there probably isn't any meaningful enhancements possible that are not already planned without taking it out of it's planned scope. Asking, or offereing, won't hurt anything however, so create an [Issue][issue] anyway.


  [DC]: http://developercertificate.org/
  [DCO]: https://github.com/chindraba-work/FixVid/blob/master/DCO.md
  [LMD]: https://github.com/chindraba-work/FixVid/blob/master/LICENSE.md
  [GPG-help]: https://help.github.com/articles/generating-a-new-gpg-key/
  [GPG]: https://www.gnupg.org/
  [kio]: https://keybase.io/
  [mit-host]: https://pgp.mit.edu/
  [app]: https://keybase.io/download
  [ncoc]: https://github.com/domgetter/NCoC
  [issue]: https://github.com/chindraba-work/FixVid/issues
  [pull]: https://github.com/chindraba-work/FixVid/pulls
