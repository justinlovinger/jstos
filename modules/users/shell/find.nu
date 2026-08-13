def find_file [] {
  let x = (_find_commandline_parts)
  let file = (fd --base-directory $x.dir --strip-cwd-prefix --color always | fzf --query $x.query)
  commandline edit $"($x.pre_query)($file)"
}

def find_tagged_file [] {
  let x = (_find_commandline_parts)
  let file = (tag find $x.dir | fzf --query $x.query)
  commandline edit $"($x.pre_query)($file)"
}

def find_tagged_file_view [] {
  let x = (_find_commandline_parts) 
  let file = (
    tag-view $x.dir -c nu -c $"tag find | fzf --query '($x.query)' | ls -l -D $in | get 0 | get target"
      | str replace $"($x.dir | path expand)/" ""
  )
  commandline edit $"($x.pre_query)($file)"
}

def _find_tagged_file_view_inner [query: string] {
  tag find | fzf --query $query | ls -l -D $in | get 0 | get target
}

def open_file [] {
  let res = (fd --strip-cwd-prefix --color always --type f --follow | fzf)
  commandline edit --accept $"o ($res)"
}

def _find_commandline_parts [] {
  # Note,
  # this assumes the cursor is at the end of the commandline.
  let buffer = (commandline)
  if ($buffer | is-empty) or ($buffer | str ends-with ' ') {
    {
      pre_query: $buffer,
      dir: ".",
      query: ""
    }
  } else {
    # Note,
    # this doesn't handle spaces in arguments.
    let args = ($buffer | split row ' ')
    let partial_path = ($args | last)
    if ($partial_path | str ends-with '/') {
      {
        pre_query: $buffer,
        dir: $partial_path,
        query: ""
      }
    } else {
      let dir = (dirname $partial_path)
      {
        pre_query: $"($args | take (($args | length) - 1) | str join ' ') ($dir)/",
        dir: $dir,
        query: (basename $partial_path)
      }
    }
  }
}
