# pacedrawing
A LuaTeX package for drawing graphs from the PACE challenge.
# About
This package allows to automatically draw graphs from various [PACE challenges](https://pacechallenge.wordpress.com) with LuaLaTeX using TikZ. It is designed with a simple one-macro layout such that everything you have to do is essentially:
```
\tikz\pace{mygraph.gr};
```
The macro supports multiple file formats and the layout of the graph can be modified in various ways. See the [documentation](https://github.com/maxbannach/pacedrawing/raw/master/doc/pacedrawing.pdf) for more details.