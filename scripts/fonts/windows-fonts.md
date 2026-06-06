# Windows font bundle notes

Recommended files to include in `docs/fonts/private/fonts.zip`:

```text
simsun.ttc      # SimSun / NSimSun
simhei.ttf      # SimHei
simkai.ttf      # KaiTi
simfang.ttf     # FangSong
msyh.ttc        # Microsoft YaHei
msyhbd.ttc      # Microsoft YaHei Bold
msjhl.ttc       # Microsoft JhengHei, optional Traditional Chinese
mingliu.ttc     # MingLiU / PMingLiU, optional Traditional Chinese
consola.ttf     # Consolas, optional
calibri.ttf     # Calibri, optional
cambria.ttc     # Cambria, optional
```

The actual file names can vary between Windows versions. What matters is the
internal font family name reported by `fc-match` after import.

Check inside the built container:

```bash
fc-match SimSun
fc-match SimHei
fc-match FangSong
fc-match KaiTi
fc-match "Microsoft YaHei"
```
