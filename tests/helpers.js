const fs = require("node:fs");
const path = require("node:path");
const assert = require("node:assert/strict");

const projectRoot = path.resolve(__dirname, "..");
const pluginDir = path.join(projectRoot, "plugin");

function pluginPath(name) {
    return path.join(pluginDir, name);
}

function extractFunction(filePath, name) {
    const source = fs.readFileSync(filePath, "utf8");
    const start = source.indexOf(`function ${name}(`);
    assert.notEqual(start, -1, `missing function ${name} in ${filePath}`);
    const bodyStart = source.indexOf("{", start);
    let depth = 0;
    let state = "code";
    let quote = "";

    for (let i = bodyStart; i < source.length; i++) {
        const c = source[i];
        const next = source[i + 1];
        if (state === "line") {
            if (c === "\n") state = "code";
            continue;
        }
        if (state === "block") {
            if (c === "*" && next === "/") {
                state = "code";
                i++;
            }
            continue;
        }
        if (state === "quote") {
            if (c === "\\") i++;
            else if (c === quote) state = "code";
            continue;
        }
        if (c === "/" && next === "/") {
            state = "line";
            i++;
        } else if (c === "/" && next === "*") {
            state = "block";
            i++;
        } else if (c === '"' || c === "'" || c === "`") {
            state = "quote";
            quote = c;
        } else if (c === "{") {
            depth++;
        } else if (c === "}") {
            depth--;
            if (depth === 0) return source.slice(start, i + 1);
        }
    }
    throw new Error(`unterminated function ${name} in ${filePath}`);
}

function compileFunction(filePath, name, root, globals = {}) {
    const source = extractFunction(filePath, name);
    const names = Object.keys(globals);
    return new Function("root", ...names, `with (root) { return (${source}); }`)(
        root,
        ...names.map(key => globals[key])
    );
}

function installFunctions(root, filePath, names, globals = {}) {
    for (const name of names)
        root[name] = compileFunction(filePath, name, root, globals);
}

function assertBalancedQml(filePath) {
    const source = fs.readFileSync(filePath, "utf8");
    const stack = [];
    const pairs = { ")": "(", "]": "[", "}": "{" };
    let state = "code";
    let quote = "";

    for (let i = 0; i < source.length; i++) {
        const c = source[i];
        const next = source[i + 1];
        if (state === "line") {
            if (c === "\n") state = "code";
            continue;
        }
        if (state === "block") {
            if (c === "*" && next === "/") {
                state = "code";
                i++;
            }
            continue;
        }
        if (state === "quote") {
            if (c === "\\") i++;
            else if (c === quote) state = "code";
            continue;
        }
        if (c === "/" && next === "/") {
            state = "line";
            i++;
        } else if (c === "/" && next === "*") {
            state = "block";
            i++;
        } else if (c === '"' || c === "'" || c === "`") {
            state = "quote";
            quote = c;
        } else if (c === "(" || c === "[" || c === "{") {
            stack.push(c);
        } else if (pairs[c]) {
            assert.equal(stack.pop(), pairs[c], `${filePath}: mismatched ${c} at offset ${i}`);
        }
    }
    assert.equal(stack.length, 0, `${filePath}: unclosed delimiters`);
    assert.equal(state === "code" || state === "line", true, `${filePath}: unterminated ${state}`);
}

function loadTabs() {
    const source = fs.readFileSync(pluginPath("NotchyTabs.js"), "utf8").replace(/^\.pragma library\s*/, "");
    return new Function(`${source}\nreturn { tabs, indexOf };`)();
}

function mockTimer() {
    return {
        stops: 0,
        restarts: 0,
        stop() { this.stops++; },
        restart() { this.restarts++; }
    };
}

module.exports = {
    projectRoot,
    pluginDir,
    pluginPath,
    extractFunction,
    compileFunction,
    installFunctions,
    assertBalancedQml,
    loadTabs,
    mockTimer
};
