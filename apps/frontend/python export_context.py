import os

# 1. 定义要忽略的文件夹和文件（黑名单，防止撑爆AI内存）
IGNORE_DIRS = {
    'build', '.dart_tool', '.git', '.idea', 'android', 'ios', 'web', 'windows', 
    'linux', 'macos', 'node_modules', '__pycache__', 'Pods'
}
IGNORE_FILES = {'pubspec.lock', 'export_context.py', '.DS_Store', 'ai_context.txt'}

# 2. 允许读取的文件后缀（精准投喂核心代码）
ALLOWED_EXTENSIONS = {'.dart', '.yaml'} # 如果是Python项目可以改成 {'.py', '.json'}

def generate_tree(dir_path, prefix=""):
    """递归生成项目目录树"""
    tree_str = ""
    try:
        items = sorted(os.listdir(dir_path))
    except Exception:
        return ""
        
    # 过滤掉不需要的目录和文件
    items = [item for item in items if item not in IGNORE_DIRS and item not in IGNORE_FILES]
    
    for i, item in enumerate(items):
        path = os.path.join(dir_path, item)
        is_last = (i == len(items) - 1)
        current_prefix = "└── " if is_last else "├── "
        
        if os.path.isdir(path):
            tree_str += f"{prefix}{current_prefix}{item}/\n"
            next_prefix = prefix + ("    " if is_last else "│   ")
            tree_str += generate_tree(path, next_prefix)
        else:
            if any(item.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                tree_str += f"{prefix}{current_prefix}{item}\n"
    return tree_str

def assemble_context(root_dir, output_file):
    """把所有核心代码组装成一个文件"""
    with open(output_file, 'w', encoding='utf-8') as outfile:
        # 写入大纲头部
        outfile.write("# PROJECT CONTEXT FOR AI\n\n")
        outfile.write("## 1. 项目目录结构拓扑图 (Project Directory Tree)\n")
        outfile.write("```text\n")
        outfile.write(generate_tree(root_dir))
        outfile.write("```\n\n")
        outfile.write("## 2. 核心文件源码详情 (Core Source Code)\n\n")
        
        # 遍历并写入文件内容
        for root, dirs, files in os.walk(root_dir):
            # 过滤掉黑名单目录
            dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
            
            for file in files:
                if file in IGNORE_FILES:
                    continue
                if not any(file.endswith(ext) for ext in ALLOWED_EXTENSIONS):
                    continue
                    
                file_path = os.path.join(root, file)
                # 计算相对路径，方便 AI 辨认
                rel_path = os.path.relpath(file_path, root_dir)
                
                outfile.write(f"### 文件路径: {rel_path}\n")
                outfile.write(f"````dart\n") # 这里可以根据语言动态修改
                try:
                    with open(file_path, 'r', encoding='utf-8') as infile:
                        outfile.write(infile.read())
                except Exception as e:
                    outfile.write(f"// 读取文件失败: {e}\n")
                outfile.write(f"\n````\n\n---\n\n")
                print(f"已成功打包: {rel_path}")

if __name__ == "__main__":
    current_dir = os.path.dirname(os.path.abspath(__file__)) if __file__ else os.getcwd()
    output_path = os.path.join(current_dir, "ai_context.txt")
    print("开始组装项目上下文...")
    assemble_context(current_dir, output_path)
    print(f"\n🎉 组装完成！请直接把项目根目录下的 [ ai_context.txt ] 投喂给 AI。")