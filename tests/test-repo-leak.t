Test native objects attached to the "repo" object gets properly released at the
end of process.

Attach an object with `__del__` to learn whether repo, ui are dropped on not.

  $ cat > $TESTTMP/printondel.py << EOF
  > class printondel(object):
  >     def __del__(self):
  >         print("__del__ called")
  > def reposetup(ui, repo):
  >     obj = printondel()
  >     repo._deltest = obj
  >     ui._deltest = obj
  > EOF

  $ setconfig extensions.leakdetect=$TESTTMP/printondel.py

No leak without extensions

  $ newrepo
  __del__ called

  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: blackbox

  $ newrepo
  __del__ called
  $ setconfig extensions.blackbox=
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: remotefilelog

  $ newrepo
  __del__ called
  $ echo remotefilelog >> .hg/requires
  $ setconfig extensions.remotefilelog= remotefilelog.cachepath=$TESTTMP/cache
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: treemanifest and fastmanifest

  $ newrepo
  __del__ called
  $ setconfig extensions.treemanifest= extensions.fastmanifest= remotefilelog.reponame=x
  $ hg log -r . -T '{node}\n'
  0000000000000000000000000000000000000000
  __del__ called
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: treemanifest only

  $ newrepo
  __del__ called
  $ setconfig extensions.treemanifest= treemanifest.treeonly=1 remotefilelog.reponame=x
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: hgsubversion

  $ newrepo
  __del__ called
  $ setconfig extensions.hgsubversion=
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: sparse

  $ newrepo
  __del__ called
  $ setconfig extensions.fbsparse=
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: commitcloud

  $ newrepo
  __del__ called
  $ setconfig extensions.infinitepush= extensions.infinitepushbackup= extensions.commitcloud=
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Fine extension: sampling

  $ newrepo
  __del__ called
  $ setconfig extensions.sampling=
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

Somehow problematic: With many extensions

  $ newrepo
  __del__ called
  $ echo remotefilelog >> .hg/requires
  $ cat >> .hg/hgrc <<EOF
  > [extensions]
  > rebase =
  > remotefilelog =
  > mergedriver =
  > pushrebase =
  > treemanifest =
  > automv=
  > blackbox=
  > crdump=
  > directaccess=
  > fastmanifest=
  > fbamend=
  > fbshow=
  > logginghelper=
  > lz4revlog=
  > patchrmdir=
  > perftweaks=
  > phabdiff=
  > phabstatus=
  > phrevset=
  > progressfile=
  > pullcreatemarkers=
  > purge=
  > rebase=
  > remotefilelog=
  > remotenames=
  > reset=
  > sampling=
  > sigtrace=
  > simplecache=
  > smartlog=
  > stat=
  > strip=
  > traceprof=
  > tweakdefaults=
  > clienttelemetry=
  > errorredirect=!
  > extorder=
  > morecolors=
  > patchbomb=
  > shelve=!
  > treedirstate=
  > hgsubversion=
  > absorb=
  > arcdiff=
  > chistedit=
  > color=
  > configwarn=
  > conflictinfo=
  > debugcommitmessage=
  > dialect=
  > fbhistedit=
  > githelp=
  > hiddenerror=
  > histedit=
  > journal=
  > morestatus=
  > myparent=
  > obsshelve=
  > rage=
  > record=
  > sshaskpass=
  > uncommit=
  > undo=
  > grpcheck=
  > checkmessagehook=
  > hgevents=
  > infinitepush=
  > infinitepushbackup=
  > commitcloud=
  > copytrace=
  > dirsync=
  > fastannotate=
  > fbconduit=
  > fbsparse=
  > gitlookup=!
  > gitrevset=!
  > mergedriver=
  > pushrebase=
  > cleanobsstore=!
  > clindex=
  > fastlog=
  > fastpartialmatch=!
  > treemanifest=
  > extorder=
  > 
  > [phases]
  > publish = False
  > 
  > [remotefilelog]
  > datapackversion = 1
  > fastdatapack = True
  > historypackv1 = True
  > reponame = x
  > cachepath = $TESTTMP/cache
  > 
  > [treemanifest]
  > treeonly=True
  > 
  > [fbconduit]
  > host=example.com
  > path=/conduit/
  > reponame=x
  > EOF
  $ hg log -r . -T '{manifest % "{node}"}\n'
  0000000000000000000000000000000000000000
  __del__ called

  $ touch x

 (this behaves differently with buck / setup.py build)

  $ hg ci -m x -A x
  __del__ called (?)

  $ hg log -r . -T '{manifest % "{node}"}\n'
  c2ffc254676c538a75532e7b6ebbbccaf98e2545
  __del__ called
