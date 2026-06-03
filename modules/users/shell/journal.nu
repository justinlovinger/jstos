def format_date_for_tag [timestamp: datetime] {
  $timestamp | format date "%Y_%m_%dt%H_%M_%S"
}

alias dt = echo $"(format_date_for_tag (date now))"

def je [ ] {
  ^$env.EDITOR $"(format_date_for_tag (date now)).md"
}

def lje [
  --copy (-c)
  --path (-p)
  --skip (-s): int = 0
  --take (-n): int = 1
  ...pattern: string
] {
  let pattern = ($pattern | str join " ")
  let paths = (ls *.md | reverse | get name | where {|x| (open --raw $x) =~ $pattern} | skip $skip | take $take | sort)
  if $copy {
    wl-copy -n ...$paths
  } else if $path {
    $paths | str join "\n"
  } else if ($paths | is-not-empty) {
    $paths | showje
  }
}

def showje [] {
  each {|path| $"# ($path)\n\n(open --raw $path)"} | str join "\n"
}
