# JSXGraph

`1.14.1/jsxgraphcore.js` is the unmodified browser distribution from
`npm pack jsxgraph@1.14.1` (`distrib/jsxgraphcore.js`). Its generated licence
notices and both upstream licence files are included alongside it.

- Upstream: https://github.com/jsxgraph/jsxgraph
- Documentation: https://jsxgraph.org/docs/
- Licence: dual MIT / LGPL; this integration uses the MIT option.
- SHA-256: `b6ebd07421e560431b888efeb472cfb7f2cfc495a853200963f97d2c28e6e474`.

The renderer passes callbacks from Chatbot's restricted maths interpreter, never
post text as JessieCode. JessieCode compilation is disabled because internal
library expressions must also work under Discourse's default CSP. Board cleanup
uses `JXG.JSXGraph.freeBoard` to release handlers and the board registry entry.
