" sword.vim

" 设置插件的名称和描述
if exists('g:loaded_sword')
  finish
endif
let g:loaded_sword = 1
let s:plugin_name = 'Sword'
let s:plugin_description = 'This is my Vim plugin called Sword.'

" 定义插件的命令和函数
command! -nargs=1 SwordDeleteFolder :call SwordDeleteFolderFunction(<f-args>)

function! SwordDeleteFolderFunction(folder)
  " 在这里编写强制删除文件夹的逻辑
  " 可以使用 Vim 的 Python 接口调用 Python 代码
  python3 << EOF
import shutil
import vim

def force_delete_folder(folder):
    try:
        shutil.rmtree(folder)
        vim.command('echo "Folder forcefully deleted: ' + folder + '"')
    except OSError as e:
        vim.command('echoerr "Failed to forcefully delete folder: ' + folder + ' - ' + str(e) + '"')

folder = vim.eval('a:folder')
force_delete_folder(folder)
EOF
endfunction


" 结束插件
