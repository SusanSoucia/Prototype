#!/usr/bin/env python3
"""Login flow diagram for 企业RAG."""
import subprocess, os

dot = r'''
digraph G {
    rankdir=TB
    newrank=true
    bgcolor="#FAFAFA"
    fontname="WenQuanYi Micro Hei"
    nodesep=0.4
    ranksep=0.5
    pad=0.3
    dpi=130
    splines=polyline

    node [fontname="WenQuanYi Micro Hei", fontsize=11, penwidth=1.5, margin="0.15,0.1"]

    // ═══ Nodes ═══
    start [label="用户访问系统", shape=oval, fillcolor="#E8F5E9", color="#43A047", fontcolor="#1B5E20", style=filled]
    submit [label="输入用户名密码\n点击登录", shape=box, fillcolor="#BBDEFB", color="#1976D2", fontcolor="#0D47A1", style=filled]
    post [label="POST /api/v1/users/login\n(username + password)", shape=box, fillcolor="#C5CAE9", color="#5C6BC0", fontcolor="#1A237E", style=filled]
    query [label="UserService 查询数据库\nSELECT * FROM users\nWHERE username = ?", shape=box, fillcolor="#FFCDD2", color="#EF5350", fontcolor="#B71C1C", style=filled]
    check [label="用户存在且\n密码匹配?", shape=diamond, fillcolor="#FFF9C4", color="#F9A825", fontcolor="#F57F17", style=filled]
    fail [label="返回 401\n用户名或密码错误", shape=box, fillcolor="#FFCDD2", color="#E53935", fontcolor="#B71C1C", style=filled]
    jwt [label="生成 JWT Token\n(含 userId, role, orgTags)\n有效期 7 天", shape=box, fillcolor="#DCEDC8", color="#66BB6A", fontcolor="#1B5E20", style=filled]
    redis [label="Redis 缓存 Token\ntoken:{tokenId}\nTTL = 1 hour", shape=box, fillcolor="#FFE0B2", color="#FB8C00", fontcolor="#E65100", style=filled]
    response [label="返回 200 OK\n{ token, userId, role }", shape=box, fillcolor="#DCEDC8", color="#66BB6A", fontcolor="#1B5E20", style=filled]
    store [label="前端存储 Token\n(localStorage)\n后续请求携带 Authorization Header", shape=box, fillcolor="#E1BEE7", color="#AB47BC", fontcolor="#4A148C", style=filled]
    filter [label="JwtAuthenticationFilter\n拦截请求 → 从 Redis 验 Token\n→ 设置 SecurityContext", shape=box, fillcolor="#B2DFDB", color="#00897B", fontcolor="#004D40", style=filled]
    done [label="登录完成\n进入首页", shape=oval, fillcolor="#E8F5E9", color="#43A047", fontcolor="#1B5E20", style=filled]
    retry [label="用户重新输入", shape=box, fillcolor="#FFECB3", color="#FFA000", fontcolor="#E65100", style=filled]

    // ═══ Edges ═══
    start -> submit
    submit -> post
    post -> query [label="Controller 委托 Service"]
    query -> check
    check -> fail [label="否", color="#E53935", fontcolor="#E53935"]
    check -> jwt [label="是", color="#43A047", fontcolor="#43A047"]
    fail -> retry
    retry -> submit [style=dashed, color="#FFA000"]
    jwt -> redis [label="写入缓存"]
    redis -> response
    response -> store
    store -> done
    done -> filter [label="后续每次请求", style=dashed, color="#00897B", fontcolor="#00897B"]

    // ═══ Title ═══
    labelloc="t"
    label="企业RAG · 登录流程"
    fontname="WenQuanYi Micro Hei"
    fontsize=18
    fontcolor="#263238"
}
'''

out_dir = '/home/susan/MySpace/codeSpace/shixun/diagrams'
dot_path = os.path.join(out_dir, '09_flow_login.dot')
png_path = os.path.join(out_dir, '09_flow_login.png')

with open(dot_path, 'w') as f:
    f.write(dot)

result = subprocess.run(
    ['dot', '-Tpng', '-Gdpi=130', dot_path, '-o', png_path],
    capture_output=True, text=True
)

if result.returncode == 0:
    size = os.path.getsize(png_path)
    print(f'Saved: {png_path} ({size} bytes)')
else:
    print(f'ERROR: {result.stderr}')
