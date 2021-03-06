xquery version "3.0";

import module namespace config="http://www.tei-c.org/tei-simple/config" at "../config.xqm";

import module namespace pmu="http://www.tei-c.org/tei-simple/xquery/util";
import module namespace odd="http://www.tei-c.org/tei-simple/odd2odd";
import module namespace tpu="http://www.tei-c.org/tei-publisher/util" at "util.xql";

declare namespace expath="http://expath.org/ns/pkg";
declare namespace output="http://www.w3.org/2010/xslt-xquery-serialization";

declare option output:method "html5";
declare option output:media-type "text/html";

declare variable $local:EXIDE :=
    let $path := collection(repo:get-root())//expath:package[@name = "http://exist-db.org/apps/eXide"]
    return
        if ($path) then
            substring-after(util:collection-name($path), repo:get-root())
        else
            ();

declare function local:load-source($href as xs:string, $line as xs:int?) {
    let $link :=
        let $path := string-join(
            (request:get-context-path(), request:get-attribute("$exist:prefix"), $local:EXIDE,
            "index.html?open=" || $href)
            , "/"
        )
        return
            replace($path, "/+", "/")
    return
        <a href="{$link}" target="eXide" class="eXide-open" data-exide-open="{$href}"
            data-exide-line="{$line}">{$href}</a>
};

declare function local:get-line($src, $line as xs:int?) {
    if ($line) then
        let $lines := tokenize($src, "\n")
        return
            subsequence($lines, $line - 1, 3) !
                replace(., "^\s*(.*?)", "$1&#10;")
    else
        ()
};

let $odd := request:get-parameter("odd", ())
let $odd :=
    if ($odd) then
        $odd
    else
        xmldb:get-child-resources($config:odd-root)[ends-with(., ".odd")]
let $result :=
    for $source in $odd
    let $odd := doc($config:odd-root || "/" || $source)
    let $pi := tpu:parse-pi($odd, ())
    for $module in
        if ($pi?output) then
            tokenize($pi?output)
        else
            ("web", "print", "latex", "epub")
    return
        try {
            for $output in pmu:process-odd(
                odd:get-compiled($config:odd-root, $source),
                $config:output-root,
                $module,
                "../" || $config:output,
                $config:module-config)
            let $file := $output?module
            return
                if ($output?error) then
                    <div class="list-group-item-danger">
                        <h5 class="list-group-item-heading">{$file}: ERROR</h5>
                        <p class="list-group-item-text">{ $output?error/error/string() }</p>
                        <pre class="list-group-item-text">{ local:get-line($output?code, $output?error/error/@line) }</pre>
                        <p class="list-group-item-text">File not saved.</p>
                    </div>
                else
                    let $src := util:binary-to-string(util:binary-doc($file))
                    let $compiled := util:compile-query($src, ())
                    return
                        if ($compiled/error) then
                            <div class="list-group-item-danger">
                                <h5 class="list-group-item-heading">{local:load-source($file, $compiled/error/@line)}:</h5>
                                <p class="list-group-item-text">{ $compiled/error/string() }</p>
                                <pre class="list-group-item-text">{ local:get-line($src, $compiled/error/@line)}</pre>
                            </div>
                        else
                            <div class="list-group-item-success">
                                <h5 class="list-group-item-heading">{$file}: OK</h5>
                            </div>
        } catch * {
            <div class="list-group-item-danger">
                <h5 class="list-group-item-heading">Error for output mode {$module}</h5>
                <p class="list-group-item-text">{ $err:description }</p>
            </div>
        }
return
    <div class="errors">
        <h4>Regenerated XQuery code from ODD files</h4>
        <div class="list-group">
        {
            $result
        }
        </div>
    </div>
