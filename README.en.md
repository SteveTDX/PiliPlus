<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png" alt="PiliPlus logo">
    <h1>PiliPlus</h1>
</div>

<div align="center">

[中文](README.md) | English

![GitHub repo size](https://img.shields.io/github/repo-size/bggRGjQaUbCoE/PiliPlus)
![GitHub Repo stars](https://img.shields.io/github/stars/bggRGjQaUbCoE/PiliPlus)
![GitHub all releases](https://img.shields.io/github/downloads/bggRGjQaUbCoE/PiliPlus/total)

</div>

<div align="center">
    <p>A third-party Bilibili client built with Flutter</p>

<img src="assets/screenshots/510shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/174shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<img src="assets/screenshots/850shots_so.png" width="32%" alt="PiliPlus mobile screenshot" />
<br/>
<img src="assets/screenshots/main_screen.png" width="96%" alt="PiliPlus desktop screenshot" />
<br/>
</div>

<br/>

## Custom changes in this fork

This fork adds the following privacy-blocking and password-protection features on top of upstream. They live under `Settings → Privacy settings`, ordered: Blocklist management → Blocked users → Block keywords → Password settings.

- [x] **Block keywords**: hide videos whose title/tags **contain** any keyword (literal substring match, no regex, to avoid injection risks)
- [x] **Blocked users**: hide all videos from any uploader whose name contains any keyword (e.g. adding "小潮" blocks uploader "小潮院长")
- [x] **Password settings**: once a password is set, Blocklist management, Blocked users and Block keywords all require it to enter
  - Digits + letters only; set an initial password on first use; changing it requires verifying the old one; both entries must match; leave blank to remove the password
- [x] Filtering covers **every user-video entry point**: feeds (both App and Web API), hot ranking, per-region ranking, related videos, and search results (video / user / live / article / bangumi / aggregated tabs)
- [x] Search results apply all three filters together: blocked users + block keywords + blocklist
- [x] Already-loaded lists are **re-filtered immediately** when keywords change — no pull-to-refresh needed
- [x] A delete icon appears on the right of every entry in Blocked users, Blocklist and Block keywords — click to remove (long-press removal still available)
- [x] Persistence matches the blocklist style (Hive local storage) with import/export support
- [x] Deliverables: Windows portable build and Android APK

<br/>

## Download

Download a build from [Releases](https://github.com/bggRGjQaUbCoE/PiliPlus/releases), or clone the repository and build it locally.

## Disclaimer

PiliPlus is a personal project developed for educational purposes, intended only for learning and testing. Please delete it within 24 hours of downloading.
All APIs used were collected from the official website. This project does not provide any cracked content.

Credit to the original project: [guozhigq/pilipala](https://github.com/guozhigq/pilipala).
Credit to the upstream project: [orz12/PiliPalaX](https://github.com/orz12/PiliPalaX).
This repository makes more extensive changes. Thank you to the original authors for sharing their work as open source.

Thank you for using PiliPlus.

## Acknowledgements

- [bilibili-API-collect](https://github.com/SocialSisterYi/bilibili-API-collect)
- [flutter_meedu_videoplayer](https://github.com/zezo357/flutter_meedu_videoplayer)
- [media-kit](https://github.com/media-kit/media-kit)
- [dio](https://pub.dev/packages/dio)
- And others

## Star History

<a href="https://star-history.dera.page/#bggRGjQaUbCoE/PiliPlus&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
   <img alt="Star History Chart" src="https://star-history.dera.page/svg?repos=bggRGjQaUbCoE/PiliPlus&type=Date" />
 </picture>
</a>