HarfBuzz release walk-through checklist:

1. Open gitk and review changes since last release.

   * `git diff $(git describe | sed 's/-.*//').. src/*.h` prints all public API
     changes.

     Document them in NEWS.  All API and API semantic changes should be clearly
     marked as API additions, API changes, or API deletions.  Document
     deprecations.  Ensure all new API / deprecations are in listed correctly in
     docs/harfbuzz-sections.txt.  If release added new API, add entry for new
     API index at the end of docs/harfbuzz-docs.xml.

     If there's a backward-incompatible API change (including deletions for API
     used anywhere), that's a release blocker.  Do NOT release.

2. Based on severity of changes, decide whether it's a minor or micro release
   number bump,

3. Search for REPLACEME on the repository and replace it with the chosen version
   for the release.

4. Make sure you have correct date and new version at the top of NEWS file,

5. Bump version in configure.ac line 3 and meson.build line 4.

6. Do "make distcheck", if it passes, you get a tarball.
   Otherwise, fix things and commit them separately before making release,
   Note: Check src/hb-version.h and make sure the new version number is
   there.  Sometimes, it does not get updated.  If that's the case,
   "touch configure.ac" and rebuild.  Also check that there is no hb-version.h
   in your build/src file. Typically it will fail the distcheck if there is.
   That's what happened to 2.0.0 going out with 1.8.0 hb-version.h...  So, that's
   a clue.

7. Now that you have release files, commit NEWS, configure.ac, and src/hb-version.h,
   as well as any REPLACEME changes you made.  The commit message is simply the
   release number.  Eg. "1.4.7"

8. "make dist" again to get a tarball with your new commit in the ChangeLog.

9. Tag the release and sign it: Eg. "git tag -s 1.4.7 -m 1.4.7".  Enter your
   GPG password.

10. Build win32 bundle.  See [README.mingw.md](README.mingw.md).

11. Quickly double-check the size of the .tar.xz and .zip files against their
    previous releases to make sure nothing bad happened.
    They should be in the ballpark, perhaps slightly larger.  Sometimes they
    do shrink, that's not by itself a stopper.

12. Push the commit and tag out: "git push --follow-tags".  Go to GitHub release
    page [here](https://github.com/harfbuzz/harfbuzz/releases), edit the tag,
    upload artefacts and NEWS entry and save.
