#!/usr/bin/env python3
"""Generate detailed backend call-relationship diagram with Graphviz.
Font: WenQuanYi Micro Hei (TTF, good CJK support in Graphviz)
"""
import subprocess, os

dot = r'''
digraph G {
    rankdir=LR
    newrank=true
    compound=true
    bgcolor="#FAFAFA"
    fontname="WenQuanYi Micro Hei"
    fontsize=16
    nodesep=0.2
    ranksep=0.35
    pad=0.15
    dpi=130
    splines=polyline

    // ═══ Global styles ═══
    node [fontname="WenQuanYi Micro Hei", fontsize=10, style="filled,rounded",
          penwidth=1.2, margin="0.12,0.07", shape=box]
    edge [fontname="WenQuanYi Micro Hei", fontsize=8, arrowsize=0.6, labelangle=0, labeldistance=2.0]

    // ═══ FRONTEND ═══
    subgraph cluster_frontend {
        label="[Web] Vue 3 前端"; fontname="WenQuanYi Micro Hei"; fontsize=12
        fontcolor="#1565C0"; style="rounded"; bgcolor="#E3F2FD"; color="#1565C0"; penwidth=2
        node [fillcolor="#BBDEFB", color="#1976D2", fontcolor="#0D47A1"]
        browser [label="浏览器\nNaive UI + TypeScript", width=1.8, height=0.8]
    }

    // ═══ SPRING BOOT APPLICATION ═══
    subgraph cluster_m1 {
        label="[App] Spring Boot M1  ·  Java 17  ·  Spring Boot 3.4.2"
        fontname="WenQuanYi Micro Hei"; fontsize=12; fontcolor="#C62828"
        style="rounded"; bgcolor="#FFF5F5"; color="#C62828"; penwidth=2.5

        // ── Controllers ──
        subgraph cluster_ctrl {
            label="表现层  ·  Controller"; fontname="WenQuanYi Micro Hei"; fontsize=10
            fontcolor="#283593"; style="rounded"; bgcolor="#E8EAF6"; color="#5C6BC0"
            node [fillcolor="#C5CAE9", color="#5C6BC0", fontcolor="#1A237E", width=1.5, height=0.55]
            uc; dc; ch; sc; ac; usc
            uc [label="UploadController"]
            dc [label="DocumentController"]
            ch [label="ChatWebSocketHandler"]
            sc [label="SearchController"]
            ac [label="AdminController"]
            usc[label="UserController"]
        }

        // ── Services ──
        subgraph cluster_svc {
            label="业务逻辑层  ·  Service"; fontname="WenQuanYi Micro Hei"; fontsize=10
            fontcolor="#B71C1C"; style="rounded"; bgcolor="#FFEBEE"; color="#EF5350"
            node [fillcolor="#FFCDD2", color="#EF5350", fontcolor="#B71C1C", width=1.6, height=0.55]
            us [label="UploadService\n上传编排"]
            ds [label="DocumentService\n文档管理"]
            chs[label="ChatHandler\nReAct Agent"]
            hss[label="HybridSearchService\n混合检索"]
            ps [label="ParseService\n文档解析"]
            vs [label="VectorizationService\n向量化"]
            atr[label="AgentToolRegistry\n工具注册"]
            users[label="UserService\n用户管理"]
            convs[label="ConversationService\n对话管理"]
            rls[label="RateLimitService\n限流控制"]
        }

        // ── Data Access ──
        subgraph cluster_dal {
            label="数据访问层  ·  Repository / External Client"; fontname="WenQuanYi Micro Hei"; fontsize=10
            fontcolor="#1B5E20"; style="rounded"; bgcolor="#E8F5E9"; color="#66BB6A"

            subgraph cluster_repo {
                label="JPA Repository"; fontname="WenQuanYi Micro Hei"; fontsize=9
                fontcolor="#2E7D32"; style="rounded,dashed"; bgcolor="#F1F8E9"; color="#81C784"
                node [fillcolor="#DCEDC8", color="#81C784", fontcolor="#1B5E20", width=1.4, height=0.5]
                fur [label="FileUploadRepo"]
                dvr [label="DocVectorRepo"]
                cr  [label="ConversationRepo"]
                ur  [label="User / OrgTagRepo"]
                mpr [label="ModelProviderRepo"]
            }

            subgraph cluster_client {
                label="External Client"; fontname="WenQuanYi Micro Hei"; fontsize=9
                fontcolor="#E65100"; style="rounded,dashed"; bgcolor="#FFF3E0"; color="#FFB74D"
                node [fillcolor="#FFE0B2", color="#FB8C00", fontcolor="#E65100", width=1.4, height=0.5]
                dskc [label="DeepSeekClient"]
                embc [label="EmbeddingClient"]
                ess  [label="ElasticsearchService"]
                kt   [label="KafkaTemplate"]
                ms   [label="MinioService"]
                rediss[label="RedisService"]
            }
        }
    }

    // ═══ DOCKER INFRASTRUCTURE ═══
    subgraph cluster_docker {
        label="[Docker] 容器化基础设施"; fontname="WenQuanYi Micro Hei"; fontsize=12
        fontcolor="#00695C"; style="rounded"; bgcolor="#E0F2F1"; color="#00897B"; penwidth=2.5
        node [fillcolor="#B2DFDB", color="#00897B", fontcolor="#004D40", width=1.8, height=0.6]

        subgraph cluster_docker_data {
            label="数据存储"; fontname="WenQuanYi Micro Hei"; fontsize=9; fontcolor="#00695C"
            style="rounded,dashed"; bgcolor="#F1F8F9"; color="#80CBC4"
            node [fillcolor="#E0F2F1", color="#4DB6AC", width=1.6, height=0.55]
            mysql [label="MySQL 8.0\n关系数据库"]
            es    [label="Elasticsearch 8.10\n向量检索引擎 (IK分词)"]
            redis [label="Redis 7.0\n缓存 / 限流 / Token"]
        }
        subgraph cluster_docker_mq {
            label="消息队列"; fontname="WenQuanYi Micro Hei"; fontsize=9; fontcolor="#00695C"
            style="rounded,dashed"; bgcolor="#F1F8F9"; color="#80CBC4"
            node [fillcolor="#E0F2F1", color="#4DB6AC", width=1.6, height=0.55]
            kafka [label="Kafka 3.2\n异步文档处理"]
        }
        subgraph cluster_docker_obj {
            label="对象存储"; fontname="WenQuanYi Micro Hei"; fontsize=9; fontcolor="#00695C"
            style="rounded,dashed"; bgcolor="#F1F8F9"; color="#80CBC4"
            node [fillcolor="#E0F2F1", color="#4DB6AC", width=1.6, height=0.55]
            minio [label="MinIO 8.5\nS3 兼容存储"]
        }
    }

    // ═══ CLOUD APIs ═══
    subgraph cluster_cloud {
        label="[Cloud] 云端 API 服务"; fontname="WenQuanYi Micro Hei"; fontsize=12
        fontcolor="#4A148C"; style="rounded,dashed"; bgcolor="#F3E5F5"; color="#AB47BC"; penwidth=2
        node [fillcolor="#E1BEE7", color="#AB47BC", fontcolor="#4A148C", width=1.8, height=0.6]
        deepseek  [label="DeepSeek API\nLLM 推理 (deepseek-chat)"]
        dashscope [label="DashScope Embedding\ntext-embedding-v4 (2048维)"]
    }

    // ═══ EMBEDDED TOOLS ═══
    subgraph cluster_embedded {
        label="[嵌入] 进程内工具"; fontname="WenQuanYi Micro Hei"; fontsize=9
        fontcolor="#4E342E"; style="rounded,dashed"; bgcolor="#EFEBE9"; color="#8D6E63"
        node [fillcolor="#D7CCC8", color="#8D6E63", fontcolor="#4E342E", width=1.4, height=0.45, fontsize=9]
        lit  [label="LiteParse\nPDF解析"]
        tika [label="Apache Tika\n文档解析"]
        hlp  [label="HanLP\n中文分词"]
    }

    // ═══════════════════════════════════════════════════
    // EDGES -- call relationships
    // ═══════════════════════════════════════════════════

    // -- Browser -> Controllers --
    browser -> uc  [label="分片上传 HTTP", color="#1565C0", fontcolor="#1565C0"]
    browser -> dc  [label="文档管理 HTTP", color="#1565C0", fontcolor="#1565C0"]
    browser -> ch  [label="问答 WebSocket", color="#1565C0", fontcolor="#1565C0", penwidth=2]
    browser -> sc  [label="搜索 HTTP", color="#1565C0", fontcolor="#1565C0"]
    browser -> ac  [label="后台管理 HTTP", color="#1565C0", fontcolor="#1565C0"]
    browser -> usc [label="登录注册 HTTP", color="#1565C0", fontcolor="#1565C0"]

    // -- Controllers -> Services --
    uc  -> us   [label="mergeFile()", color="#5C6BC0", fontcolor="#5C6BC0"]
    dc  -> ds   [label="CRUD / 重索引", color="#5C6BC0", fontcolor="#5C6BC0"]
    ch  -> chs  [label="processMessage()", color="#5C6BC0", fontcolor="#5C6BC0", penwidth=2]
    sc  -> hss  [label="search()", color="#5C6BC0", fontcolor="#5C6BC0"]
    ac  -> users [label="用户管理", color="#5C6BC0", fontcolor="#5C6BC0"]
    ac  -> ds   [label="文档管理", color="#5C6BC0", fontcolor="#5C6BC0", style=dotted]
    usc -> users [label="认证鉴权", color="#5C6BC0", fontcolor="#5C6BC0"]

    // -- Services -> Repositories / Clients --
    us  -> kt     [label="发送处理任务", color="#EF5350", fontcolor="#EF5350"]
    us  -> ms     [label="分片上传/合并", color="#EF5350", fontcolor="#EF5350"]
    us  -> fur    [label="元数据写入", color="#EF5350", fontcolor="#EF5350"]
    us  -> rediss [label="上传进度BitMap", color="#EF5350", fontcolor="#EF5350", style=dotted]
    ds  -> fur    [label="查询/更新/删除", color="#EF5350", fontcolor="#EF5350"]
    ds  -> dvr    [label="删除分块", color="#EF5350", fontcolor="#EF5350", style=dotted]
    chs -> dskc   [label="ReAct推理\n(最多4轮8工具)", color="#EF5350", fontcolor="#EF5350", penwidth=2]
    chs -> embc   [label="查询向量化", color="#EF5350", fontcolor="#EF5350", style=dotted]
    chs -> ess    [label="混合检索", color="#EF5350", fontcolor="#EF5350"]
    chs -> cr     [label="对话持久化", color="#EF5350", fontcolor="#EF5350"]
    chs -> rediss [label="对话缓存\n(最近20条)", color="#EF5350", fontcolor="#EF5350", style=dotted]
    hss -> embc   [label="查询Embedding", color="#EF5350", fontcolor="#EF5350"]
    hss -> ess    [label="KNN+BM25检索", color="#EF5350", fontcolor="#EF5350", penwidth=2]
    hss -> fur    [label="联查文件名", color="#EF5350", fontcolor="#EF5350", style=dotted]
    ps  -> lit    [label="PDF解析", color="#EF5350", fontcolor="#EF5350"]
    ps  -> tika   [label="DOCX/TXT/MD", color="#EF5350", fontcolor="#EF5350"]
    ps  -> hlp    [label="分词切块", color="#EF5350", fontcolor="#EF5350"]
    ps  -> dvr    [label="存储分块", color="#EF5350", fontcolor="#EF5350"]
    vs  -> embc   [label="批量向量化\n(batch=10)", color="#EF5350", fontcolor="#EF5350", penwidth=2]
    vs  -> dvr    [label="读取分块文本", color="#EF5350", fontcolor="#EF5350"]
    vs  -> ess    [label="Bulk写入索引", color="#EF5350", fontcolor="#EF5350"]
    vs  -> fur    [label="更新向量化状态", color="#EF5350", fontcolor="#EF5350", style=dotted]
    atr -> ess    [label="knowledge_stats", color="#EF5350", fontcolor="#EF5350", style=dotted]
    atr -> dskc   [label="generate_summary", color="#EF5350", fontcolor="#EF5350", style=dotted]
    users -> ur   [label="CRUD", color="#EF5350", fontcolor="#EF5350"]
    users -> rediss [label="Token缓存", color="#EF5350", fontcolor="#EF5350", style=dotted]
    convs -> cr   [label="历史查询", color="#EF5350", fontcolor="#EF5350"]
    rls  -> rediss [label="滑动窗口计数", color="#EF5350", fontcolor="#EF5350"]

    // -- Clients/Repos -> Docker Containers --
    fur    -> mysql [label="JDBC", color="#00897B", fontcolor="#00897B"]
    dvr    -> mysql [label="JDBC", color="#00897B", fontcolor="#00897B"]
    cr     -> mysql [label="JDBC", color="#00897B", fontcolor="#00897B"]
    ur     -> mysql [label="JDBC", color="#00897B", fontcolor="#00897B"]
    mpr    -> mysql [label="JDBC", color="#00897B", fontcolor="#00897B"]
    ess    -> es    [label="REST API\nKNN+BM25", color="#00897B", fontcolor="#00897B", penwidth=2]
    kt     -> kafka [label="事务性发送\nfile-processing-topic1", color="#00897B", fontcolor="#00897B", penwidth=2]
    ms     -> minio [label="S3 API\n分片/合并/预签名", color="#00897B", fontcolor="#00897B"]
    rediss -> redis [label="RESP协议\n多用途缓存", color="#00897B", fontcolor="#00897B"]

    // -- Clients -> Cloud APIs --
    dskc -> deepseek  [label="HTTP POST\n/v1/chat/completions\nSSE流式输出", color="#AB47BC", fontcolor="#AB47BC", penwidth=2]
    embc -> dashscope [label="HTTP POST\n/v1/embeddings\n批量 size=10", color="#AB47BC", fontcolor="#AB47BC", penwidth=2]

    // -- Kafka Consumer async callback --
    kafka -> ps [label="[异步] Consumer\n解析->切分", color="#FF6D00", fontcolor="#FF6D00",
                 penwidth=2, style="bold,dashed", constraint=false]
    kafka -> vs [label="[异步] 向量化\n->ES索引", color="#FF6D00", fontcolor="#FF6D00",
                 penwidth=2, style="bold,dashed", constraint=false]

    // -- WebSocket streaming (bidirectional) --
    chs -> ch [label="逐token流式推送\n+ 工具调用状态", color="#7B1FA2", fontcolor="#7B1FA2",
               penwidth=1.5, style=bold, dir=both, arrowtail="normal"]

    // ═══ Legend ═══
    {
        rank=sink
        legend [shape=plaintext, fillcolor="#FAFAFA", color="#CFD8DC", fontsize=9,
                fontcolor="#78909C", width=0, height=0, margin=0, label=<
            <table border="0" cellborder="0" cellspacing="3" cellpadding="2">
                <tr><td align="right"><b>图例:</b></td>
                    <td><font color="#1565C0"><b>---</b></font></td><td>HTTP/WS 请求</td>
                    <td><font color="#5C6BC0"><b>---</b></font></td><td>Controller-Service</td>
                    <td><font color="#EF5350"><b>---</b></font></td><td>Service-DA层</td>
                    <td><font color="#00897B"><b>---</b></font></td><td>协议通信</td>
                    <td><font color="#AB47BC"><b>---</b></font></td><td>云端 API</td>
                    <td><font color="#FF6D00"><b>- -</b></font></td><td>Kafka 异步</td>
                    <td><font color="#5C6BC0"><b>...</b></font></td><td>辅助调用</td>
                </tr>
            </table>
        >]
    }
}
'''

out_dir = '/home/susan/MySpace/codeSpace/shixun/diagrams'
dot_path = os.path.join(out_dir, '08_backend_arch.dot')
png_path = os.path.join(out_dir, '08_backend_arch.png')

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
