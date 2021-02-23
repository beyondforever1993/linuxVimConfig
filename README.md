# Linux Vim 配置

1. 支持gtags, 需要gtags_cscope.vim插件;
2. Youcompleteme支持clangd, 需10.0.0以上版本，不然会出现找不到部分头文件的错误提示;

ctags 命令
```shell
ctags --fields=+niazS --extras=+q --c++-kinds=+px --c-kinds=+px --output-format=e-ctags -R -f .tags *
```
