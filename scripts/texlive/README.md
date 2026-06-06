# TeX Live layer

`Dockerfile-full-1` owns the slow TeX Live work:

- apt mirror setup
- common runtime tools
- open-source font packages
- helper scripts
- `tlmgr update --self`
- `tlmgr update --all`
- `tlmgr install scheme-full`
- core package smoke test

Do not put private Windows fonts or font alias experiments here.
