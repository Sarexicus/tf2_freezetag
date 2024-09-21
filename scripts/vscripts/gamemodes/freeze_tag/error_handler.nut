// Credit: Lizard of Oz

::detectedIssues <- {};
::ErrorHandler <- function(e)
{
    local stackInfo = getstackinfos(2);
    local key = format("'%s' @ %s#%d", e, stackInfo.src, stackInfo.line);
    local target = GetSourceTV() || GetListenServerHost();
    if (!target) return;

    if (!(key in detectedIssues))
    {
        detectedIssues[key] <- [e, 1];
        PrintError(target, "A NEW ERROR HAS OCCURRED", e);
    }
    else
    {
        detectedIssues[key][1]++;
        ClientPrint(target, 3, format("A ERROR HAS OCCURRED [%d] TIMES: [%s]", detectedIssues[key][1], key));
    }
}
seterrorhandler(ErrorHandler);

::PrintError <- function(player, title, e, printfunc = null)
{
    if (!printfunc)
        printfunc = @(m) ClientPrint(player, 3, m);
    printfunc(format("\n%s [%s]", title, e));
    printfunc("CALLSTACK");
    local s, l = 3;
    while (s = getstackinfos(l++))
        printfunc(format("*::[%s <- function()] %s line [%d]", s.func, s.src, s.line));
    printfunc("LOCALS");
    if (s = getstackinfos(3))
        foreach (n, v in s.locals)
        {
            local t = type(v);
            t ==    "null" ? printfunc(format("[%s] NULL"  , n))    :
            t == "integer" ? printfunc(format("[%s] %d"    , n, v)) :
            t ==   "float" ? printfunc(format("[%s] %.14g" , n, v)) :
            t ==  "string" ? printfunc(format("[%s] \"%s\"", n, v)) :
                             printfunc(format("[%s] %s %s" , n, t, v.tostring()));
        }
}