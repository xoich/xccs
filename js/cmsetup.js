CodeMirror.defineSimpleMode("xccs", {
    // The start state contains the rules that are intially used
    start: [
        {regex: /(?:proc|set)\b/, token: "keyword", next: "norm"},
        {regex: /let\b/, token: "keyword", next: "varbind"},
        {regex: /\/\/.*/, token: "comment"},
    ],
    varbind: [
        {regex: /[0-9]+/, token: "number"},
        {regex: /\/\/.*/, token: "comment"},
        {regex: /(?:proc|set)\b/, token: "keyword", next: "norm"},
        {regex: /let\b/, token: "keyword"}
    ],
    norm: [
        {regex: /(?:proc|set)\b/, token: "keyword"},
        {regex: /\/\/.*/, token: "comment"},
        {regex: /[+|\.\\\/]/, token: "operator"},
        {regex: /let\b/, token: "keyword", next: "varbind"},
        {regex: /<[^>]*?>/, token: "string"},
        {regex: /nil/, token: "atom"},
        {regex: /([a-zA-Z][\w_]*)(\s*\()/, token: ["variable-2", "null"], push: "params"},
        {regex: /('[a-zA-Z][\w_]*)(\s*\()/, token: ["variable-3", "null"], push: "params"},
        {regex: /[a-zA-Z][\w_]*/, token: "variable-2"},
        {regex: /'[a-zA-Z][\w_]*/, token: "variable-3"}
    ],
    params: [
        {regex: /[0-9]+/, token: "number"},
        {regex: /\(/, token: "null", push: "params"},
        {regex: /\)/, token: "null", pop: true}
    ],
    meta: {
        lineComment: "//"
    }
});
cminput = CodeMirror.fromTextArea(document.getElementById("input"),
                                  {lineNumbers: true,
                                   mode: "xccs",
                                   theme: "gruvbox-dark"});

let outwrap = document.getElementById("outwrap");
outwrap.style.display = "block";
cmoutput = CodeMirror.fromTextArea(document.getElementById("output"),
                                   {lineNumbers: true,
                                    mode: null,
                                    theme: "gruvbox-dark"});

outwrap.style.display = "none";
