#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import os

W, H = 1100, 780
img = Image.new('RGB', (W, H), '#FAFAFA')
draw = ImageDraw.Draw(img)

font_title = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 26)
font_layer = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 18)
font_box_title = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 14)
font_box_text = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc', 12)
font_box_sub = ImageFont.truetype('/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc', 12)

MARGIN = 20
START_Y = 50
layer_gap = 8
pad = 5

layers = [
    ('表现层', '#E3F2FD', '#1565C0', [
        ('Chat\n问答页', ''),
        ('KnowledgeBase\n知识库', ''),
        ('Login\n登录/注册', ''),
        ('User\n用户管理', ''),
        ('Personal\n个人中心', ''),
        ('UsageMonitor\n仪表盘', ''),
    ], [
        ('组件', 'ChatMessage  ChatInput  UploadDialog  SearchDialog  FilePreview'),
    ]),
    ('业务逻辑层', '#FCE4EC', '#C62828', [
        ('authStore\n认证·用户·角色', ''),
        ('chatStore\nWebSocket·消息·流式', ''),
        ('kbStore\n上传队列·进度', ''),
        ('themeStore\nrouteStore\ntabStore', ''),
        ('路由守卫\nauthGuard  roleGuard', ''),
    ], None),
    ('数据访问层', '#E8EAF6', '#283593', [
        ('auth.ts\n登录·注册·Token', ''),
        ('knowledge.ts\n文档CRUD·上传', ''),
        ('chat.ts\n对话·历史查询', ''),
        ('search.ts  user.ts\nroute.ts', ''),
        ('@sa/axios\nJWT注入·401拦截', ''),
        ('useWebSocket\n自动重连·心跳', ''),
    ], None),
]

n = len(layers)
avail = H - START_Y - MARGIN
total_gap = layer_gap * (n - 1)
layer_h = (avail - total_gap) // n

def measure(text, font):
    bbox = draw.textbbox((0, 0), text, font=font)
    return bbox[2] - bbox[0], bbox[3] - bbox[1]

def draw_card(ix, iy, iw, ih, label_color, text, sublabel):
    lines = text.split('\n')
    cx = ix + iw // 2

    # calc heights
    line_hs = []
    for j, line in enumerate(lines):
        is_title = (j == 0)
        ft = font_box_title if is_title else font_box_text
        _, h = measure(line, ft)
        line_hs.append(h + 4)

    total_th = sum(line_hs)

    if sublabel:
        sw, sh = measure(sublabel, font_box_sub)
        sw += 12; sh = 18
        sub_x = ix + (iw - sw) // 2
        draw.rounded_rectangle([sub_x, iy+4, sub_x+sw, iy+4+sh], radius=9, fill=label_color)
        draw.text((sub_x+sw//2, iy+4+sh//2), sublabel, fill='#FFFFFF', font=font_box_sub, anchor='mm')
        text_top = iy + 4 + sh + 4
        ty = text_top + (iy + ih - text_top - 4 - total_th) // 2
    else:
        ty = iy + (ih - total_th) // 2

    for j, line in enumerate(lines):
        is_title = (j == 0)
        ft = font_box_title if is_title else font_box_text
        tc = '#263238' if is_title else '#607D8B'
        draw.text((cx, ty), line, fill=tc, font=ft, anchor='mt')
        ty += line_hs[j]

draw.text((W//2, 16), '企业RAG 前端分层架构', fill='#263238', font=font_title, anchor='mt')

for li, (label, bg, label_color, row1, row2) in enumerate(layers):
    y0 = START_Y + li * (layer_h + layer_gap)
    y1 = y0 + layer_h

    draw.rounded_rectangle([MARGIN, y0, W-MARGIN, y1], radius=6, fill=bg, outline='#CFD8DC', width=1)

    # Label pill
    lbl_w = 22
    lbl_x = MARGIN + pad
    lbl_h = layer_h - pad*2
    draw.rounded_rectangle([lbl_x, y0+pad, lbl_x+lbl_w, y0+pad+lbl_h], radius=5, fill=label_color)
    char_gap = min(20, (lbl_h - 10) // len(label))
    for ci, ch in enumerate(label):
        draw.text((lbl_x+lbl_w//2, y0+pad+12+ci*char_gap), ch, fill='#FFFFFF', font=font_layer, anchor='mt')

    item_start = MARGIN + lbl_w + pad*3
    n_items = len(row1)
    gap = 6
    avail_w = W - MARGIN - item_start - MARGIN

    if row2 is None:
        # single row
        item_w = (avail_w - (n_items-1)*gap) // n_items
        iy = y0 + pad
        ih = layer_h - pad*2
        for ii, (text, sub) in enumerate(row1):
            ix = item_start + ii * (item_w + gap)
            draw.rounded_rectangle([ix, iy, ix+item_w, iy+ih], radius=4, fill='#FFFFFF', outline='#E0E0E0', width=1)
            draw_card(ix, iy, item_w, ih, label_color, text, sub)
    else:
        # two rows: row1 items evenly split above, row2 items span full width below
        row1_h = int((layer_h - pad*2) * 0.58)
        row2_h = layer_h - pad*2 - row1_h - 4
        r1y = y0 + pad
        r2y = r1y + row1_h + 4

        item_w = (avail_w - (n_items-1)*gap) // n_items
        for ii, (text, sub) in enumerate(row1):
            ix = item_start + ii * (item_w + gap)
            draw.rounded_rectangle([ix, r1y, ix+item_w, r1y+row1_h], radius=4, fill='#FFFFFF', outline='#E0E0E0', width=1)
            draw_card(ix, r1y, item_w, row1_h, label_color, text, sub)

        # row2: full-width card(s)
        r2_items = len(row2)
        r2_gap = 4
        r2_item_w = (avail_w - (r2_items-1)*r2_gap) // r2_items
        for ii, (sub, text) in enumerate(row2):
            ix = item_start + ii * (r2_item_w + r2_gap)
            draw.rounded_rectangle([ix, r2y, ix+r2_item_w, r2y+row2_h], radius=4, fill='#FFFFFF', outline='#E0E0E0', width=1)
            draw_card(ix, r2y, r2_item_w, row2_h, label_color, text, sub)

out = '/home/susan/MySpace/codeSpace/shixun/diagrams/07_frontend_tech_stack.png'
img.save(out, 'PNG', optimize=True)
print(f'Saved: {out} ({os.path.getsize(out)} bytes)')
