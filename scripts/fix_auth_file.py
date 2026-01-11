#!/usr/bin/env python3
"""
凭证文件修复工具
用法: python fix_auth_file.py <原文件路径> <邮箱>
示例: python fix_auth_file.py "composite-rhino-483712-j9-1767877333.json" "2304917439@qq.com"
"""

import json
import sys
import os
from datetime import datetime

def fix_auth_file(input_path: str, email: str, output_dir: str = None) -> str:
    """
    修复凭证文件格式
    
    Args:
        input_path: 原凭证文件路径
        email: 正确的邮箱账号
        output_dir: 输出目录（默认为当前目录）
    
    Returns:
        新文件路径
    """
    # 读取原文件
    with open(input_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # 生成新文件名（邮箱中的特殊字符替换为下划线）
    safe_email = email.replace('@', '_').replace('.', '_')
    new_filename = f"antigravity-{safe_email}.json"
    
    # 确定输出路径
    if output_dir:
        new_path = os.path.join(output_dir, new_filename)
    else:
        new_path = new_filename
    
    # 当前时间
    now = datetime.now().astimezone().isoformat()
    
    # 修复/添加必要字段
    fixed_data = {
        "account": email,
        "account_type": "oauth",
        "auth_index": data.get("auth_index", ""),
        "created_at": data.get("created_at", now),
        "disabled": data.get("disabled", False),
        "email": email,
        "id": new_filename,
        "label": email,
        "modtime": now,
        "name": new_filename,
        "path": f"/data/.cli-proxy-api/{new_filename}",
        "provider": "antigravity",
        "runtime_only": data.get("runtime_only", False),
        "size": 0,  # 将在写入后更新
        "source": "file",
        "status": "active",
        "status_message": "",
        "type": "antigravity",
        "unavailable": False,
        "updated_at": now,
    }
    
    # 保留原文件中的 OAuth token 相关字段（如果有）
    oauth_fields = ["access_token", "refresh_token", "expires_at", "token_type", "project_id"]
    for field in oauth_fields:
        if field in data:
            fixed_data[field] = data[field]
    
    # 写入新文件
    with open(new_path, 'w', encoding='utf-8') as f:
        json.dump(fixed_data, f, indent=2, ensure_ascii=False)
    
    # 更新 size 字段
    fixed_data["size"] = os.path.getsize(new_path)
    with open(new_path, 'w', encoding='utf-8') as f:
        json.dump(fixed_data, f, indent=2, ensure_ascii=False)
    
    return new_path


def main():
    if len(sys.argv) < 3:
        print("用法: python fix_auth_file.py <原文件路径> <邮箱>")
        print("示例: python fix_auth_file.py composite-rhino.json 2304917439@qq.com")
        sys.exit(1)
    
    input_path = sys.argv[1]
    email = sys.argv[2]
    output_dir = sys.argv[3] if len(sys.argv) > 3 else None
    
    if not os.path.exists(input_path):
        print(f"错误: 文件不存在 - {input_path}")
        sys.exit(1)
    
    new_path = fix_auth_file(input_path, email, output_dir)
    print(f"✅ 修复完成!")
    print(f"   原文件: {input_path}")
    print(f"   新文件: {new_path}")
    print(f"   邮箱: {email}")


if __name__ == "__main__":
    main()
