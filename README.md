# Requirements:

* jq to parse berlin's API responses (in $PATH)
* ipfs to do ipfs things (in $PATH)
* a running ipfs daemon that is online

# How to run:

Change to the directory containing guix-ipfs-cache and run
<code>bash run.sh</code>

# Rationale

TL;DR: ipfs allows sharing of whole directory structures under persistent names (ipns), even if the directory structure changes. Since <code>guix package --substitute-url="http://localhost:8080/some/path/to/repository/of/packages"</code> expects a certain directory structure we can try and share this directory structure via ipfs/ipns. Click this link for an example:

http://ipfs.io/ipns/QmPMJYhxbeaSYXzNLMRbvvJknpYcJG9DcG8h2kJJmukd9i

(This is running via the gateway to ipfs provided by the ipfs people). Once a user has a running ipfs daemon locally they can use this:

http://localhost:8080/ipns/QmPMJYhxbeaSYXzNLMRbvvJknpYcJG9DcG8h2kJJmukd9i

as substitute-url.

## ipfs daemon as "local" guix substitute-mirror

The ipfs daemon provides a local http-proxy to the ipfs network that allows retrieving files by their CID (content-id), a unique identifier for the respective file that derived from its contents. The default port of this proxy is TCP/8080. An url to retrieve a file from the daemon would e.g. look like this:

http://localhost:8080/ipfs/QmbiJmTexTp1YBv3s7eKXDTzKGaKMTLGuns2xscmhdhadu

These can be retrieved by any HTTP-Client:

<pre>
$ curl http://localhost:8080/ipfs/QmbiJmTexTp1YBv3s7eKXDTzKGaKMTLGuns2xscmhdhadu
StorePath: /gnu/store/y857mykfnc9vd1sc2lqz5g35l111fp71-opensmtpd-test
URL: nar/gzip/y857mykfnc9vd1sc2lqz5g35l111fp71-opensmtpd-test
Compression: gzip
NarHash: sha256:136lm3fxh4kbsgz32157cnmyypgynkkmrqqb03biym1nm6cdwyv7
NarSize: 2600
References: 2sznibwwvp6x0ha2j6n8s1z1brf8ra4q-opensmtpd-test-builder
FileSize: 894
System: x86_64-linux
Deriver: 8aski1xwcn6lj112yc9ylgp2y3c7sj83-opensmtpd-test.drv
Signature: 1;berlin.guixsd.org;KHNpZ25hdHVyZSAKIChkYXRhIAogIChmbGFncyByZmM2OTc5KQogIChoYXNoIHNoYTI1NiAjQTdCQzIwRjU0QzQ1NEYyRUE1QjQ1NTU1QzExN0VDOEYzMjA1RjlEQkM4N0ZDMzc4M0M1NjBCREM5REZCQUI3QyMpCiAgKQogKHNpZy12YWwgCiAgKGVjZHNhIAogICAociAjQzhGRjZGMTMyNUFENzRBRjhDRDVDOTEzREE2NThFMjM5QzJCOEQ1QjZGNzM5REM1ODdDMTVERDVCODA3RkQjKQogICAocyAjMENCMTA3NUI5NDI5MUNEODVFMDI5NDQ4N0YzMTk1QUI5RTI5ODE5ODBFQzg2RDc1NDZDMDYyRjQ1NTNBRjEzQiMpCiAgICkKICApCiAocHVibGljLWtleSAKICAoZWNjIAogICAoY3VydmUgRWQyNTUxOSkKICAgKHEgIzhEMTU2RjI5NUQyNEIwRDlBODZGQTU3NDFBODQwRkYyRDI0RjYwRjdCNkM0MTM0ODE0QUQ1NTYyNTk3MUIzOTQjKQogICApCiAgKQogKQo=
</pre>

Individual files can be added to the ipfs-network with the <code>ipfs add</code>. There are other mechanisms, but we'll stick to this high level view for now.

In addition to providing files, ipfs supports directories (also identified by CIDs). These directories are implemented as Merkle-DAGs -- a form of cryptographic data structure that is a directed acyclic graph (DAG). 

<pre>
$ mkdir test
$ touch test/foo
$ ipfs add -r test/
added QmbFMke1KXqnYyBBWxB74N4c5SBnJMVAiMNRcGu6x1AwQH test/foo
added QmWLU2zkdpnTSzKEu1RLN43mFjayCJzXrnE8nP1KT2htNd test
 0 B / ? [----------------------------------------------------------------------------------------------------=]   0.00%
</pre>

One nice feature is that the ipfs daemon proxy supports lookup of files relative to a directory by clear names:

<pre>
$ curl http://localhost:8080/ipfs/QmWLU2zkdpnTSzKEu1RLN43mFjayCJzXrnE8nP1KT2htNd/foo
$ 
</pre>

In this case the file was empty. To illustrate one important point about directories in ipfs, let's change the file's content:

<pre>
$ echo "Hello, world!" > test/foo 
$ ipfs add -r test/
added QmeeLUVdiSTTKQqhWqsffYDtNvvvcTfJdotkNyi1KDEJtQ test/foo
added QmT429U7M2Civz8qmkA6uZ5tvLJ9njQAvzsX6BvWodJ3i1 test
 14 B / 14 B [=================================================================================================] 100.00%
</pre>

The attentive reader will have noticed that the resulting CID of the <code>test</code> directory has changed. This will happen whenever a file's content changed or the structure of the directory changed (e.g. by adding new or removing existing files from the directory).

<pre>
$ curl http://localhost:8080/ipfs/QmT429U7M2Civz8qmkA6uZ5tvLJ9njQAvzsX6BvWodJ3i1/foo
Hello, world!
</pre>

At this point we can imagine how a local ipfs daemon can act as substitute-url for guix: We simply publish a directory structure on ipfs that resembles the structure the <code>guix package</code> expects, namely:

* A bunch of <code>narinfo</code> files directly in the root of the directory
* A nix-cache-control text file in the root of the directory
* A bunch of <code>nar</code> files in a <code>nar/gzip</code> subdirectory.

An example of this would be <code>https://ipfs.io/ipfs/QmR6y77ijvafrZanwxw63Q2QHkMBK4PbhTxSgTC9m3Un3o</code> (ipfs.io runs a gateway similar to the local ipfs daemon, so please click on this link to browse the directory).

A user could, in principle, now use an url like this in a call to <code>guix package</code>.

<pre>
guix package --substitute-url="http://localhost:8080/ipfs/QmR6y77ijvafrZanwxw63Q2QHkMBK4PbhTxSgTC9m3Un3o https://mirror.hydra.gnu.org" -i emacs
</pre>

The attentive reader will have noticed one weakness of this approach: Everytime the root-directory of this repository changes the resulting URL will change as well. This would imply that users would have to constantly update the URL they use in the <code>substitute-url</code> parameter to <code>guix package</code>. To remedy situations like this ipfs has implemented a name system called ipns.

ipfs allows to publish ipns names that are mutable. The name is the hash of a public part of a public/private key pair, and per default <code>ipfs name publish</code> uses the ipfs node's key.

<pre>
$ ipfs name publish QmT429U7M2Civz8qmkA6uZ5tvLJ9njQAvzsX6BvWodJ3i1
Published to QmaeGpMRsHmeVaQFRnwtuZYdSdVgbc3Y64aDFs1ya8Frnb: /ipfs/QmT429U7M2Civz8qmkA6uZ5tvLJ9njQAvzsX6BvWodJ3i1
</pre>

This basically completes the necessary components to provide a stable substitute-url for guix that can have changing contents. Checkout https://ipfs.io/ipns/QmPMJYhxbeaSYXzNLMRbvvJknpYcJG9DcG8h2kJJmukd9i which is the address that this repository's code running on a server produces. Note how the first part of the url changed from <code>ipfs</code> to <code>ipns</code> (note: like said above the ipns name is specific to the particular ipfs node publishing that name):

<code>
guix package --substitute-url="http://localhost:8080/ipns/QmPMJYhxbeaSYXzNLMRbvvJknpYcJG9DcG8h2kJJmukd9i https://mirror.hydra.gnu.org" -i emacs
</code>

# Fetching substitutes from berlin.guixsd.org and publishing them via ipfs

The code in this repository contains a bunch of shell scripts (with no error handling whatsoever - so beware, it's just a proof of concept) that perform these steps:

* Fetch narinfos into <code>cache/</code>
* Fetch the respective nar into <code>cache/nar/gzip</code>
* build up directory structure that <code>guix package</code> expects
* publish them all to ipfs
* update the ipns name to point to the latest version

with binaries retrieved from berlin.guixsd.org's API that informs about finished builds.

# An optimization for size, speed and profit

Once a directory reaches a certain size, adding it recursively with <code>ipfs add</code> becomes slow as a dog (disk IO alone being a bottleneck). Also just keeping all files on disk is using up precious disk space while the promise of ipfs is that the swarm can take over hosting "responsibility". Luckily there is a way to add entries to a directory object directly without having to rerun <code>ipfs add -r</code> over and over again.

TODO: implement and document this section's content ;)

