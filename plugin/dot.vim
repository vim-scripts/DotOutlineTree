" Dot Outline Tree
"
" Summary: Helps you edit a dot-stractured text.
"
" Version: 0.2.0
" Last Change: 01-Mar-2005.
" Maintainer: Shuhei Kubota <shu_brief AT yahoo.co.jp>
"
" Detailed Description:
"
"   Make an outline tree of a buffer (containing dot-structured text). Also this
"   plugin enables jumping to a node and operating nodes.
"
"   [What's the dot-structured text?]
"
"   It's a kind of text file which forms tree structure. Following is an
"   instance.
"
"   . a
"   text of a
"   .. a-b
"   text of a-b
"   . b
"   text of b
"
"   Each line which starts with '.' represent title. The others are text. You
"   can change heading marks('.' by default). See g:DOT_headingMark.
"
" Install Description:
"
"   Put this plugin in your plugin directory(e.g. $VIMRUNTIME/plugin). Then
"   restart VIM.
"
" Usage:
"
"   [Commands]
"
"   :DotOutlineTree
"   :RefreshDotOutlineTree
"
"       The former command constructs an outline tree, and shows an outline
"       window.  In some cases, even if a buffer is modified, its outline tree
"       is not refreshed. Use :RefreshDotOutlineTree(the latter one). But it do
"       scanning the buffer, structuring nodes, and outputting the data every
"       time. This makes VIM slow.
"
"   [Variables]
"
"   (The right hand value is a default value.)
"
"   g:DOT_refreshWhenModified = 1 (not 0)
"
"       If this is not 0 and a buffer is modified, :DotOutlineTree re-constructs
"       the outline tree automatically. If this is 0, no automatic
"       re-construction is done. You may want to use :RefreshDotOutlineTree.
"
"   g:DOT_newMethod = 'vertical new'
"
"       Commands above creates a new window. This variable specifies the way the
"       new window is created.
"
"       e.g. 'new'
"
"   g:DOT_windowWidth = 30
"
"       This affects if g:DOT_newMethod is VERTICAL.
"
"   g:DOT_headingMark = '.'
"
"       Specifies a character as a heading mark. It can't be a sequence.
"
"   [Key Mappings]
"
"       <Enter>:
"           jumps to the node.
"       r:
"           refreshes the outline tree. Same as :RefreshDotOutlineTree.
"       <Esc>: 
"           escapes from the outline window, leaving it shown.
"       q:
"           escapes from the outline window, hiding it.
"
"       <C-J>:
"           creates an uncle node.
"       <C-K>:
"           creates a (younger) sibling node.
"       <C-L>:
"           creates a child node.
"       d:
"           deletes a node. If the node which the cursor is on  has children,
"           they are deleted recursively.
"
"       <C-U>:
"           moves nodes in backward(upper) direction.
"           e.g. (<C-U>ing on a node `hoge')
"             .foo     .hoge
"             .hoge => ..piyo
"             ..piyo   .foo
"             .bar     .bar
"       <C-D>:
"           moves nodes in forward(lower) direction.
"           e.g. (<C-D>ing on a node `hoge')
"             .foo     .foo
"             .hoge => .bar
"             ..piyo   .hoge
"             .bar     ..piyo
"
"       <<:
"           brings up levels of nodes.
"           e.g.
"             ...hoge => ..hoge
"       >>:
"           brings down levels of nodes.
"           e.g.
"             ...hoge => ....hoge


" when the target buffer is modified, the outline tree is re-structured.
if !exists('g:DOT_refreshWhenModified')
    let g:DOT_refreshWhenModified = 1
endif

" used when outline window is beging shown.
" specifies the way to showing the outline window.
if !exists('g:DOT_newMethod')
    let g:DOT_newMethod = 'vertical new'
endif

" specifies width of the outline window.
" this affects if g:DOT_newMethod is VERTICAL.
if !exists('g:DOT_windowWidth')
    let g:DOT_windowWidth = 30
endif

if !exists('g:DOT_headingMark')
    let g:DOT_headingMark = '.'
endif


" Memorandum
"
" s:nodeCount
" s:nodeTitle{ [0, s:nodeCount) }
" s:nodeLevel{ [0, s:nodeCount + 2) } " the latter two are sentries
" s:nodePos{ [0, s:nodeCount + 2) }   " too
"
" s:cursorPos
" s:dotBufferNumber
" s:lastModifiedTime
" s:headingMarkRegexp
" s:titleRegexp
" s:levelRegexp


command! DotOutlineTree call <SID>DotOutlineTree(0)
command! RefreshDotOutlineTree call <SID>DotOutlineTree(1)


" keymaps on the outline window
function! s:SetKeyMappings()
    " jumping
    noremap  <buffer> <silent>  <Enter>  :call <SID>JumpToNode(line('.') - 1)<CR>
    noremap  <buffer> <silent>  <C-J>    :call <SID>JumpToNode(line('.') - 1)<CR>

    " refreshing
    noremap  <buffer> <silent>  r  <C-W><C-P>:RefreshDotOutlineTree<CR>

    " escaping from the outline window
    noremap  <buffer> <silent>  <Esc>  :call <SID>EscapeToBuffer()<CR>
    " hiding the outline window
    noremap  <buffer> <silent>  q      :bdelete!<CR>

    " operating nodes

    " creating
    noremap  <buffer> <silent>  <C-J>  :call <SID>CreateUncle(line('.') - 1)<CR>
    noremap  <buffer> <silent>  <C-K>  :call <SID>CreateSibling(line('.') - 1)<CR>
    noremap  <buffer> <silent>  <C-L>  :call <SID>CreateChild(line('.') - 1)<CR>

    " deleting
    noremap  <buffer> <silent>  d  :call <SID>DeleteNode(line('.') - 1)<CR>

    " changing level
    noremap  <buffer> <silent>  <<  :call <SID>BringUp(line('.') - 1)<CR>
    noremap  <buffer> <silent>  >>  :call <SID>BringDown(line('.') - 1)<CR>

    " moving
    noremap  <buffer> <silent>  <C-U>  :call <SID>MoveBackward(line('.') - 1)<CR>
    noremap  <buffer> <silent>  <C-D>  :call <SID>MoveForward(line('.') - 1)<CR>
endfunction


function! s:SetSyntax()
    highlight  dotNode  term=underline cterm=underline gui=underline
    syntax  match  dotNode  '[^ ]\+.*$' 

    "highlight  dotEven  term=reverse cterm=reverse gui=reverse
    "syntax  match  dotEven  '^\(\(  \)\+\)\{2\}[^ ].*$'
    "syntax  match  dotEven  '^[^ ].*$'
endfunction


function! s:DotOutlineTree(refresh)
    if bufname('%') == 'DOT_TREE'
        wincmd p
    endif

    call s:redefineHeadingMarkRegexp()

    let currBufferNumber = bufnr('%')
    if a:refresh || s:IsTimeToRefresh(currBufferNumber)
        let s:dotBufferNumber = currBufferNumber 
        call s:MakeDotTree()
    endif
    let s:cursorPos = line('.')

    if s:nodeCount == 0
        echoe 'It is requred that this buffer contains at least one node.'
        return
    endif

    call s:OpenTreeWindow('DOT_TREE', g:DOT_newMethod)

    call s:PrintOutlineTree()

    " move to the node where the cursor is on
    let i = 0
    while i < s:nodeCount
        if s:cursorPos < s:nodePos{i}
            if i == 0
                execute 1
            else
                execute i
            endif
            break
        endif
        let i = i + 1
    endwhile
    "normal V

endfunction


function! s:redefineHeadingMarkRegexp()
    let s:headingMarkRegexp = escape(g:DOT_headingMark, '.+\\/')
    let s:titleRegexp = '^' . s:headingMarkRegexp . '\+\s*\(.*\)$'
    let s:levelRegexp = '^\(' . s:headingMarkRegexp . '\+\).*$'
endfunction


function! s:IsTimeToRefresh(currBufferNumber)
    return !exists('s:dotBufferNumber') || (s:dotBufferNumber != a:currBufferNumber) || (g:DOT_refreshWhenModified && ((s:lastModifiedTime < getftime(bufname(s:dotBufferNumber))) || &modified))
endfunction


function! s:MakeDotTree()
    let s:nodeCount = 0

    let i = 0
    let lineCount = line('$')

    while i < lineCount
        let line = getline(i + 1)

        if line == '' || char2nr(line) != char2nr(g:DOT_headingMark)
            let i = i + 1
            continue
        endif

        let s:nodeTitle{s:nodeCount} = substitute(line, s:titleRegexp, '\1', '')
        let s:nodeLevel{s:nodeCount} = strlen(substitute(line, s:levelRegexp, '\1', '')) / strlen(g:DOT_headingMark)
        let s:nodePos{s:nodeCount} = i + 1
        let s:nodeCount = s:nodeCount + 1

        let i = i + 1
    endwhile

    " dummy data as sentries
    let s:nodePos{s:nodeCount} = lineCount + 1
    let s:nodeLevel{s:nodeCount} = 1
    let s:nodePos{s:nodeCount + 1} = lineCount + 1
    let s:nodeLevel{s:nodeCount + 1} = 1

    let s:lastModifiedTime = localtime()
endfunction


function! s:PrintOutlineTree()

    setlocal modifiable noreadonly

    " clear
    %delete

    " keep lines
    if s:nodeCount > 1
        execute 'normal ' . (s:nodeCount - 1) . "o\<Esc>"
    endif

    let i = 0
    while i < s:nodeCount - 1
        call setline(i + 1, s:RepeatString('  ', s:nodeLevel{i} - 1) . s:nodeTitle{i})
        let i = i + 1
    endwhile

    call setline(i + 1, s:RepeatString('  ', s:nodeLevel{i} - 1) . s:nodeTitle{i})

    setlocal nomodifiable readonly
endfunction


function! s:JumpToNode(nodeNum)
    call s:OpenWindow(s:dotBufferNumber, g:DOT_newMethod, 0)
    execute s:nodePos{a:nodeNum}
    normal zt
    if s:IsInSameNode(a:nodeNum)
        execute s:cursorPos
    endif
endfunction


function! s:IsInSameNode(nodeNum)
    return ((s:nodePos{a:nodeNum} <= s:cursorPos) && (s:cursorPos < s:nodePos{a:nodeNum + 1}))
endfunction


function! s:EscapeToBuffer()
    call s:OpenWindow(s:dotBufferNumber, g:DOT_newMethod, 0)
    execute s:cursorPos
endfunction


function! s:CreateUncle(self)
    let insertPos = s:GetLastNephewOrSibling(a:self)

    if insertPos == s:nodeCount
        let insertPos = s:nodeCount - 1
    endif

    call s:CreateNode(insertPos, s:nodeLevel{a:self} - 1, 'Uncle')
endfunction


function! s:CreateSibling(self)
    let insertPos = s:GetNextSibling(a:self)

    if insertPos == s:nodeCount
        let insertPos = s:nodeCount - 1
    endif

    call s:CreateNode(insertPos, s:nodeLevel{a:self}, 'Sibling')
endfunction


function! s:CreateChild(self)
    call s:CreateNode(a:self, s:nodeLevel{a:self} + 1, 'Child')
endfunction


function! s:CreateNode(pos, level, prompt)
    let title = input(a:prompt . ': ')
    if title == ''
        return
    endif
    if char2nr(title) == char2nr(g:DOT_headingMark)
        let title = ' ' . title
    endif

    call s:EscapeToBuffer()

    let insertPos = s:nodePos{a:pos + 1}
    execute insertPos - 1
    normal o
    call setline(insertPos, s:RepeatString(g:DOT_headingMark, a:level) . title)

    call s:DotOutlineTree(1)
    execute a:pos + 2
endfunction


function! s:DeleteNode(root)
    let lastDescendant = s:LastDescendantOf(a:root)

    let msg = 'Are you sure to delete '
    if a:root != lastDescendant
        let msg = msg . 'these nodes'
        "execute 'normal vV' . (lastDescendant - a:root) . 'jo'
    else
        let msg = msg . '`' . s:nodeTitle{a:root} . "'"
        "normal vV
    endif
    let msg = msg . '? [y/N]'

    echo msg

    if char2nr(tolower(nr2char(getchar()))) == char2nr('y')
        call s:EscapeToBuffer()

        silent execute s:nodePos{a:root} . ',' . (s:nodePos{s:LastDescendantOf(a:root) + 1} - 1) . 'delete'

        call s:DotOutlineTree(1)
        execute a:root
    endif

    " clear the prev echo
    normal :<Esc>
endfunction


function! s:BringUp(first)
    let i = a:first
    let lastDescendant = s:LastDescendantOf(a:first)
    if lastDescendant == s:nodeCount
        let lastDescendant = s:nodeCount - 1
    endif

    if s:nodeLevel{a:first} == 1
        return
    endif

    call s:EscapeToBuffer()
    while i <= lastDescendant
        call setline(s:nodePos{i}, substitute(getline(s:nodePos{i}), s:headingMarkRegexp . '\(.\+\)', '\1', ''))

        let i = i + 1
    endwhile
    call s:DotOutlineTree(1)
    execute a:first + 1
endfunction


function! s:BringDown(first)
    let i = a:first
    let lastDescendant = s:LastDescendantOf(a:first)
    if lastDescendant == s:nodeCount
        let lastDescendant = s:nodeCount - 1
    endif

    call s:EscapeToBuffer()
    while i <= lastDescendant
        call setline(s:nodePos{i}, g:DOT_headingMark . getline(s:nodePos{i}))

        let i = i + 1
    endwhile
    call s:DotOutlineTree(1)
    execute a:first + 1
endfunction


function! s:MoveBackward(root)
    if a:root == 0
        return
    endif

    let dest = s:FindBackwardMovablePos(a:root)
    if dest == s:nodeCount
        let dest = 0
    endif

    call s:MoveNode(a:root, s:LastDescendantOf(a:root), dest)

    call s:DotOutlineTree(1)
    execute dest + 1
endfunction


function! s:MoveForward(root)
    if a:root == s:nodeCount - 1
        return
    endif

    let term = s:LastDescendantOf(a:root)

    let dest = s:FindForwardMovablePos(term)
    " dest is ...
    " a:root
    "   :
    "   term
    " some_node <- dest
    "   :
    if dest == s:nodeCount
        return
    endif
    let dest = s:FindForwardMovablePos(dest)
    " dest is ...
    " a:root
    "   :
    "   term
    " some_node
    "   :
    " another_node <- dest
    "   :

    call s:MoveNode(a:root, term, dest)

    call s:DotOutlineTree(1)
    execute dest - (a:root - term)
endfunction


function! s:MoveNode(srcNodeBegin, srcNodeTerm, dest)
    "echom 'a:srcNodeBegin: ' . a:srcNodeBegin
    "echom 'a:srcNodeTerm: ' . a:srcNodeTerm
    "echom 'a:dest: ' . a:dest

    let deleteBegin = s:nodePos{a:srcNodeBegin}
    let deleteEnd   = s:nodePos{a:srcNodeTerm + 1}

    let insertPos = s:nodePos{a:dest}
    let insertingLast = 0

    if deleteBegin <= insertPos
        "echom 'Moving Forward'

        let insertingLast = (insertPos == s:nodePos{s:nodeCount})

        let diff = deleteEnd - deleteBegin
        let insertPos = insertPos - diff
    endif
    "echom 'deleteBegin: ' . deleteBegin
    "echom 'deleteEnd: ' . deleteEnd
    "echom 'insertPos: ' . insertPos

    let deleteRange = deleteBegin . ',' . (deleteEnd - 1)

    call s:EscapeToBuffer()

    silent execute deleteRange . 'delete'
    if insertingLast
        silent execute '$'
        normal p
    else
        silent execute insertPos
        normal P
    endif
endfunction


function! s:FindBackwardMovablePos(root)
    let rootLevel = s:nodeLevel{a:root}

    let i = a:root - 1
    while -1 < i
        if s:nodeLevel{i} <= rootLevel
            return i
        endif

        let i = i - 1
    endwhile

    return s:nodeCount
endfunction


function! s:FindForwardMovablePos(termNode)
    let rootLevel = s:nodeLevel{a:termNode}
    
    let i = a:termNode + 1
    while i < s:nodeCount
        if s:nodeLevel{i} <= rootLevel
            return i
        endif

        let i = i + 1
    endwhile

    return s:nodeCount
endfunction


function! s:LastDescendantOf(root)
    let rootLevel = s:nodeLevel{a:root}

    let i = a:root + 1
    while i < s:nodeCount
        if s:nodeLevel{i} <= rootLevel
            return i - 1
        endif

        let i = i + 1
    endwhile

    return s:nodeCount
endfunction


function! s:GetLastNephewOrSibling(root)
    let rootLevel = s:nodeLevel{a:root}

    let i = a:root + 1
    while i < s:nodeCount
        if s:nodeLevel{i} < rootLevel
            return i - 1
        endif

        let i = i + 1
    endwhile

    return s:nodeCount
endfunction


function! s:GetNextSibling(root)
    let rootLevel = s:nodeLevel{a:root}

    let i = a:root + 1
    while i < s:nodeCount
        if s:nodeLevel{i} <= rootLevel
            return i - 1
        endif

        let i = i + 1
    endwhile

    return s:nodeCount
endfunction


function! s:OpenTreeWindow(name, method)
    call s:OpenWindow(a:name, a:method, 1)
    execute g:DOT_windowWidth . 'wincmd |'

    setlocal nowrap nonumber buftype=nofile bufhidden=delete noswapfile

    call s:SetKeyMappings()
    call s:SetSyntax()
endfunction!


function! s:RepeatString(str, times)
    let result = ''

    let i = 0
    while i < a:times
        let result = result . a:str

        let i = i + 1
    endwhile

    return result
endfunction


function! s:OpenWindow(buffName, method, forceNewWindow)
    let window = bufwinnr(a:buffName)

    if window != -1
        execute window . 'wincmd w'
        return window
    endif

    if a:forceNewWindow
        execute a:method . ' ' . a:buffName
    else
        if type(a:buffName) == 0 " Number
            execute 'buffer ' . a:buffName
        else
            execute 'edit ' . a:buffName
        endif
    endif

    return winnr()
endfunction

" vim:ts=4:sts=4:sw=4:tw=80:et:
