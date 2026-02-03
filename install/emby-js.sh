#!/bin/bash
# Emby-Javascript-Details 容器部署脚本
# 适用于群晖/威联通/TrueNAS等NAS设备的Docker环境
# 通过SSH远程执行，支持交互式配置

set -e

# 定义必需的文件列表
REQUIRED_FILES=(
  "emby_detail_page.js"
  "trailer_more_button.js"
  "list_page_trailer.js"
  "actor_page.js"
  "config.json"
)

# 项目文件服务器地址
REPO_BASE_URL="http://www.micimo.top/emby/Emby-Javascript-Details"
TEMP_DIR="/tmp/emby-js-deploy-$$"
CUSTOM_DIR="custom"

# 终端颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# 日志输出函数
info()    { echo -e "${BLUE}[INFO]${NC} $1"; }
success() { echo -e "${GREEN}[✓]${NC} $1"; }
warn()    { echo -e "${YELLOW}[!]${NC} $1"; }
error()   { echo -e "${RED}[✗]${NC} $1" >&2; }
header()  { echo -e "${PURPLE}$1${NC}"; }
step()    { echo -e "${CYAN}▶ $1${NC}"; }

# 检查系统命令是否存在
check_command() {
  if ! command -v "$1" &> /dev/null; then
    error "系统缺少必要命令: $1"
    exit 1
  fi
}

# 从指定服务器下载必需文件
download_files() {
  header "
╔════════════════════════════════════════════════════════════╗
║   Emby-Javascript-Details 容器部署脚本                    ║
║   文件源: ${REPO_BASE_URL}                                ║
╚════════════════════════════════════════════════════════════╝
"
  
  info "创建临时工作目录: $TEMP_DIR"
  mkdir -p "$TEMP_DIR"
  
  step "开始下载项目文件..."
  
  local success_count=0
  local fail_count=0
  
  for file in "${REQUIRED_FILES[@]}"; do
    url="${REPO_BASE_URL}/${file}"
    dest="${TEMP_DIR}/${file}"
    
    echo -n "  下载 $file ... "
    
    # 优先使用curl，备选wget
    if command -v curl &> /dev/null; then
      if curl -sSL -o "$dest" "$url" -w "%{http_code}" | grep -q "200"; then
        success "成功"
        ((success_count++))
      else
        error "失败"
        ((fail_count++))
      fi
    elif command -v wget &> /dev/null; then
      if wget -q -O "$dest" "$url" 2>/dev/null; then
        success "成功"
        ((success_count++))
      else
        error "失败"
        ((fail_count++))
      fi
    else
      error "系统缺少下载工具"
      return 1
    fi
  done
  
  echo ""
  info "下载统计: ${success_count} 成功, ${fail_count} 失败"
  
  if [ $fail_count -gt 0 ]; then
    error "部分文件下载失败，请检查网络连接和服务器地址"
    return 1
  fi
  
  success "所有项目文件下载完成"
}

# 交互式配置向导，生成config.json
interactive_config() {
  header "
╔════════════════════════════════════════════════════════════╗
║              Emby-Javascript-Details 配置向导              ║
╚════════════════════════════════════════════════════════════╝
"
  
  # 基本功能设置
  echo -e "${CYAN}【1. 基本功能设置】${NC}"
  echo "----------------------------------------"
  read -p "  启用脚本功能 (true/false, 默认true): " ENABLE
  ENABLE=${ENABLE:-true}
  echo ""
  
  # 详情页显示选项
  echo -e "${CYAN}【2. 媒体详情页显示设置】${NC}"
  echo "----------------------------------------"
  read -p "  显示评分信息 (true/false, 默认true): " SHOW_RATING
  SHOW_RATING=${SHOW_RATING:-true}
  
  read -p "  显示类型标签 (true/false, 默认true): " SHOW_GENRES
  SHOW_GENRES=${SHOW_GENRES:-true}
  
  read -p "  显示导演信息 (true/false, 默认true): " SHOW_DIRECTOR
  SHOW_DIRECTOR=${SHOW_DIRECTOR:-true}
  
  read -p "  显示演员列表 (true/false, 默认true): " SHOW_CAST
  SHOW_CAST=${SHOW_CAST:-true}
  
  read -p "  显示媒体时长 (true/false, 默认true): " SHOW_RUNTIME
  SHOW_RUNTIME=${SHOW_RUNTIME:-true}
  
  read -p "  显示发行年份 (true/false, 默认true): " SHOW_YEAR
  SHOW_YEAR=${SHOW_YEAR:-true}
  
  read -p "  显示制作公司 (true/false, 默认true): " SHOW_STUDIO
  SHOW_STUDIO=${SHOW_STUDIO:-true}
  
  read -p "  显示媒体标语 (true/false, 默认true): " SHOW_TAGLINE
  SHOW_TAGLINE=${SHOW_TAGLINE:-true}
  echo ""
  
  # 预告片按钮设置
  echo -e "${CYAN}【3. 预告片按钮设置】${NC}"
  echo "----------------------------------------"
  read -p "  启用预告片按钮 (true/false, 默认true): " TRAILER_BTN_ENABLE
  TRAILER_BTN_ENABLE=${TRAILER_BTN_ENABLE:-true}
  
  read -p "  按钮显示位置 (top/bottom, 默认bottom): " TRAILER_BTN_POS
  TRAILER_BTN_POS=${TRAILER_BTN_POS:-bottom}
  
  read -p "  按钮显示文本 (默认'播放预告片'): " TRAILER_BTN_TEXT
  TRAILER_BTN_TEXT=${TRAILER_BTN_TEXT:-"播放预告片"}
  
  read -p "  按钮显示图标 (true/false, 默认true): " TRAILER_BTN_ICON
  TRAILER_BTN_ICON=${TRAILER_BTN_ICON:-true}
  echo ""
  
  # 列表页预告片设置
  echo -e "${CYAN}【4. 列表页预告片设置】${NC}"
  echo "----------------------------------------"
  read -p "  启用列表页预告片 (true/false, 默认false): " LIST_TRAILER_ENABLE
  LIST_TRAILER_ENABLE=${LIST_TRAILER_ENABLE:-false}
  
  read -p "  悬停自动播放 (true/false, 默认true): " LIST_TRAILER_AUTO
  LIST_TRAILER_AUTO=${LIST_TRAILER_AUTO:-true}
  
  read -p "  预告片播放音量 (0-100, 默认30): " LIST_TRAILER_VOL
  LIST_TRAILER_VOL=${LIST_TRAILER_VOL:-30}
  echo ""
  
  # 演员页增强设置
  echo -e "${CYAN}【5. 演员页面增强设置】${NC}"
  echo "----------------------------------------"
  read -p "  启用演员页增强 (true/false, 默认true): " ACTOR_PAGE_ENABLE
  ACTOR_PAGE_ENABLE=${ACTOR_PAGE_ENABLE:-true}
  
  read -p "  显示演员作品列表 (true/false, 默认true): " ACTOR_FILMOGRAPHY
  ACTOR_FILMOGRAPHY=${ACTOR_FILMOGRAPHY:-true}
  
  read -p "  显示演员个人简介 (true/false, 默认true): " ACTOR_BIOGRAPHY
  ACTOR_BIOGRAPHY=${ACTOR_BIOGRAPHY:-true}
  echo ""
  
  # 视觉样式设置
  echo -e "${CYAN}【6. 视觉样式设置】${NC}"
  echo "----------------------------------------"
  read -p "  全局字体大小 (默认14): " STYLE_FONT_SIZE
  STYLE_FONT_SIZE=${STYLE_FONT_SIZE:-14}
  
  read -p "  文字颜色 (#十六进制, 默认#ffffff): " STYLE_FONT_COLOR
  STYLE_FONT_COLOR=${STYLE_FONT_COLOR:-"#ffffff"}
  
  read -p "  背景颜色 (CSS格式, 默认rgba(0,0,0,0.7)): " STYLE_BG_COLOR
  STYLE_BG_COLOR=${STYLE_BG_COLOR:-"rgba(0,0,0,0.7)"}
  
  read -p "  元素圆角大小 (默认8): " STYLE_BORDER_RADIUS
  STYLE_BORDER_RADIUS=${STYLE_BORDER_RADIUS:-8}
  echo ""
  
  # 高级参数设置
  echo -e "${CYAN}【7. 高级参数设置】${NC}"
  echo "----------------------------------------"
  read -p "  最大显示演员数量 (默认10): " MAX_CAST
  MAX_CAST=${MAX_CAST:-10}
  
  read -p "  最大显示类型数量 (默认5): " MAX_GENRES
  MAX_GENRES=${MAX_GENRES:-5}
  
  read -p "  数据缓存时间(秒) (默认3600): " CACHE_TIME
  CACHE_TIME=${CACHE_TIME:-3600}
  
  # 生成标准JSON格式配置文件
  cat > "${TEMP_DIR}/config.json" <<EOF
{
  "enable": ${ENABLE},
  "debug": false,
  "showRating": ${SHOW_RATING},
  "showGenres": ${SHOW_GENRES},
  "showDirector": ${SHOW_DIRECTOR},
  "showCast": ${SHOW_CAST},
  "showRuntime": ${SHOW_RUNTIME},
  "showYear": ${SHOW_YEAR},
  "showStudio": ${SHOW_STUDIO},
  "showTagline": ${SHOW_TAGLINE},
  "trailerButton": {
    "enable": ${TRAILER_BTN_ENABLE},
    "position": "${TRAILER_BTN_POS}",
    "text": "${TRAILER_BTN_TEXT}",
    "showIcon": ${TRAILER_BTN_ICON}
  },
  "listPageTrailer": {
    "enable": ${LIST_TRAILER_ENABLE},
    "autoPlay": ${LIST_TRAILER_AUTO},
    "volume": ${LIST_TRAILER_VOL}
  },
  "actorPage": {
    "enable": ${ACTOR_PAGE_ENABLE},
    "showFilmography": ${ACTOR_FILMOGRAPHY},
    "showBiography": ${ACTOR_BIOGRAPHY}
  },
  "style": {
    "fontSize": "${STYLE_FONT_SIZE}",
    "fontColor": "${STYLE_FONT_COLOR}",
    "backgroundColor": "${STYLE_BG_COLOR}",
    "borderRadius": "${STYLE_BORDER_RADIUS}"
  },
  "maxCast": ${MAX_CAST},
  "maxGenres": ${MAX_GENRES},
  "cacheTime": ${CACHE_TIME}
}
EOF

  success "配置文件已生成并保存至临时目录"
  echo ""
}

# 检测运行中的Emby容器及挂载配置
detect_emby_container() {
  if ! command -v docker &> /dev/null; then
    error "系统未安装Docker，请确认Emby以容器方式运行"
    return 1
  fi

  step "扫描Docker容器..."
  
  # 查找包含emby或jellyfin关键词的运行中容器
  CONTAINERS=$(docker ps --format "{{.Names}}\t{{.Image}}" 2>/dev/null | grep -iE "emby|jellyfin" | awk '{print $1}')
  
  if [ -z "$CONTAINERS" ]; then
    error "未检测到Emby/Jellyfin容器"
    error "请确认以下事项:"
    error "  • Docker服务正在运行"
    error "  • Emby容器已启动并运行"
    error "  • 容器名称包含'emby'或'jellyfin'关键词"
    echo ""
    read -p "是否手动指定容器名称? (y/n): " MANUAL
    if [ "$MANUAL" == "y" ] || [ "$MANUAL" == "Y" ]; then
      read -p "请输入容器名称: " CONTAINER_NAME
      if [ -z "$CONTAINER_NAME" ]; then
        error "容器名称不能为空"
        return 1
      fi
      success "使用手动指定的容器: $CONTAINER_NAME"
    else
      return 1
    fi
  else
    # 处理单容器或多容器情况
    IFS=$'\n' read -d '' -r -a CONTAINER_LIST <<< "$CONTAINERS"
    
    if [ ${#CONTAINER_LIST[@]} -eq 1 ]; then
      CONTAINER_NAME="${CONTAINER_LIST[0]}"
      success "检测到唯一Emby容器: $CONTAINER_NAME"
    else
      warn "检测到多个媒体服务器容器:"
      for i in "${!CONTAINER_LIST[@]}"; do
        echo "  $i) ${CONTAINER_LIST[$i]}"
      done
      read -p "请选择目标容器编号 (默认0): " CHOICE
      CHOICE=${CHOICE:-0}
      CONTAINER_NAME="${CONTAINER_LIST[$CHOICE]}"
      success "已选择容器: $CONTAINER_NAME"
    fi
  fi

  # 检测容器卷挂载配置
  step "分析容器卷挂载配置..."
  
  MOUNTS=$(docker inspect "$CONTAINER_NAME" --format '{{range .Mounts}}{{.Source}} {{.Destination}}{{"\n"}}{{end}}' 2>/dev/null | grep -E "/config|/system|/emby" || true)
  
  if [ -n "$MOUNTS" ]; then
    # 优先匹配Emby标准Web目录路径
    WEB_MOUNT=$(echo "$MOUNTS" | grep -E "/config/emby/web|/system|/emby/web" | head -1)
    
    if [ -n "$WEB_MOUNT" ]; then
      WEB_HOST_DIR=$(echo "$WEB_MOUNT" | awk '{print $1}')
      WEB_CONTAINER_DIR=$(echo "$WEB_MOUNT" | awk '{print $2}')
      
      info "检测到Web资源挂载点:"
      info "  宿主机路径: $WEB_HOST_DIR"
      info "  容器内路径: $WEB_CONTAINER_DIR"
      
      DEPLOY_MODE="host"
      DEPLOY_PATH="${WEB_HOST_DIR}/${CUSTOM_DIR}"
      
      # 确保部署目录存在
      mkdir -p "$DEPLOY_PATH"
      
      success "将通过宿主机挂载目录部署文件"
    else
      # 使用第一个挂载点作为基础路径
      FIRST_MOUNT=$(echo "$MOUNTS" | head -1)
      WEB_HOST_DIR=$(echo "$FIRST_MOUNT" | awk '{print $1}')
      DEPLOY_MODE="host"
      DEPLOY_PATH="${WEB_HOST_DIR}/emby/web/${CUSTOM_DIR}"
      mkdir -p "$DEPLOY_PATH"
      info "使用默认Web路径: $DEPLOY_PATH"
    fi
  else
    # 无挂载点时使用docker cp方式
    warn "未检测到有效卷挂载，将使用容器内直接部署模式"
    DEPLOY_MODE="docker_cp"
    
    # 根据镜像类型确定容器内路径
    IMAGE_NAME=$(docker inspect "$CONTAINER_NAME" --format='{{.Config.Image}}' 2>/dev/null)
    if echo "$IMAGE_NAME" | grep -qi "jellyfin"; then
      DEPLOY_PATH="/var/lib/jellyfin/web/${CUSTOM_DIR}"
    else
      DEPLOY_PATH="/config/emby/web/${CUSTOM_DIR}"
    fi
    
    info "容器内部署路径: $DEPLOY_PATH"
  fi
  
  echo ""
}

# 将文件部署到Emby容器环境
deploy_to_container() {
  step "开始部署文件到Emby环境..."
  
  if [ "$DEPLOY_MODE" == "host" ]; then
    # 宿主机挂载目录部署模式
    info "部署模式: 宿主机卷挂载"
    info "目标路径: $DEPLOY_PATH"
    
    mkdir -p "$DEPLOY_PATH"
    
    local deployed=0
    for file in "${REQUIRED_FILES[@]}"; do
      if cp "${TEMP_DIR}/${file}" "${DEPLOY_PATH}/" 2>/dev/null; then
        success "部署文件: ${file}"
        ((deployed++))
      else
        error "部署失败: ${file}"
      fi
    done
    
    echo ""
    info "部署结果: ${deployed}/${#REQUIRED_FILES[@]} 个文件成功"
    
    # 询问是否重启容器
    echo ""
    read -p "是否立即重启Emby容器以应用更改? (y/n, 默认y): " RESTART
    RESTART=${RESTART:-y}
    
    if [ "$RESTART" == "y" ] || [ "$RESTART" == "Y" ]; then
      step "重启容器: $CONTAINER_NAME"
      if docker restart "$CONTAINER_NAME" >/dev/null 2>&1; then
        success "容器重启成功"
      else
        error "容器重启失败，请手动执行: docker restart $CONTAINER_NAME"
      fi
    else
      warn "已跳过容器重启，更改将在下次容器启动时生效"
    fi
    
  else
    # docker cp 直接部署模式
    info "部署模式: 容器内直接复制"
    info "目标路径: $DEPLOY_PATH"
    
    # 确保容器内目录存在
    docker exec "$CONTAINER_NAME" mkdir -p "$DEPLOY_PATH" 2>/dev/null || true
    
    local deployed=0
    for file in "${REQUIRED_FILES[@]}"; do
      if docker cp "${TEMP_DIR}/${file}" "${CONTAINER_NAME}:${DEPLOY_PATH}/" 2>/dev/null; then
        success "部署文件: ${file}"
        ((deployed++))
      else
        error "部署失败: ${file}"
      fi
    done
    
    echo ""
    info "部署结果: ${deployed}/${#REQUIRED_FILES[@]} 个文件成功"
    
    # 自动重启容器确保生效
    step "重启容器: $CONTAINER_NAME"
    if docker restart "$CONTAINER_NAME" >/dev/null 2>&1; then
      success "容器重启成功"
    else
      error "容器重启失败"
    fi
  fi
  
  echo ""
}

# 非交互式模式使用默认配置
non_interactive_mode() {
  step "使用默认配置参数生成配置文件..."
  
  # 生成标准默认配置
  cat > "${TEMP_DIR}/config.json" <<EOF
{
  "enable": true,
  "debug": false,
  "showRating": true,
  "showGenres": true,
  "showDirector": true,
  "showCast": true,
  "showRuntime": true,
  "showYear": true,
  "showStudio": true,
  "showTagline": true,
  "trailerButton": {
    "enable": true,
    "position": "bottom",
    "text": "播放预告片",
    "showIcon": true
  },
  "listPageTrailer": {
    "enable": false,
    "autoPlay": true,
    "volume": 30
  },
  "actorPage": {
    "enable": true,
    "showFilmography": true,
    "showBiography": true
  },
  "style": {
    "fontSize": "14",
    "fontColor": "#ffffff",
    "backgroundColor": "rgba(0,0,0,0.7)",
    "borderRadius": "8"
  },
  "maxCast": 10,
  "maxGenres": 5,
  "cacheTime": 3600
}
EOF
  
  success "默认配置文件生成完成"
}

# 显示部署完成信息和使用指南
show_completion_info() {
  header "
╔════════════════════════════════════════════════════════════╗
║                      部署完成                              ║
╚════════════════════════════════════════════════════════════╝
"
  
  echo -e "${CYAN}后续操作步骤:${NC}"
  echo "  1. 清除浏览器缓存数据 (Ctrl+Shift+Delete)"
  echo "  2. 强制刷新Emby网页界面 (Ctrl+F5 或 Cmd+Shift+R)"
  echo "  3. 访问媒体详情页验证功能效果"
  echo ""
  
  echo -e "${CYAN}配置文件位置:${NC}"
  if [ "$DEPLOY_MODE" == "host" ]; then
    echo "  宿主机路径: ${GREEN}${DEPLOY_PATH}/config.json${NC}"
    echo "  可直接编辑此文件调整配置参数"
  else
    echo "  容器内路径: ${GREEN}${DEPLOY_PATH}/config.json${NC}"
    echo "  编辑命令: ${YELLOW}docker exec -it ${CONTAINER_NAME} vi ${DEPLOY_PATH}/config.json${NC}"
  fi
  echo ""
  
  echo -e "${CYAN}重要提示:${NC}"
  echo "  • 配置修改后必须重启Emby容器才能生效"
  echo "  • 重启命令: ${YELLOW}docker restart ${CONTAINER_NAME}${NC}"
  echo "  • 如遇显示问题，请检查浏览器开发者工具控制台(F12)"
  echo ""
  
  echo -e "${CYAN}已部署文件清单:${NC}"
  for file in "${REQUIRED_FILES[@]}"; do
    echo "  ✓ ${file}"
  done
  echo ""
  
  echo -e "${BLUE}项目资源地址: ${REPO_BASE_URL}${NC}"
  echo ""
}

# 主执行流程
main() {
  # 验证系统依赖
  check_command docker
  
  if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
    error "系统缺少下载工具，请安装curl或wget"
    exit 1
  fi
  
  # 设置退出时清理临时目录
  trap "rm -rf $TEMP_DIR" EXIT
  
  # 下载项目文件
  if ! download_files; then
    error "项目文件下载失败，终止部署流程"
    exit 1
  fi
  
  # 判断终端交互能力
  if [ -t 1 ]; then
    INTERACTIVE=true
  else
    warn "检测到非交互式终端环境，将使用默认配置参数"
    INTERACTIVE=false
  fi
  
  # 生成配置文件
  if [ "$INTERACTIVE" = true ]; then
    interactive_config
  else
    non_interactive_mode
  fi
  
  # 容器环境检测
  if ! detect_emby_container; then
    error "容器环境检测失败，终止部署流程"
    exit 1
  fi
  
  # 执行文件部署
  if ! deploy_to_container; then
    error "文件部署过程出现错误"
    exit 1
  fi
  
  # 显示完成信息
  show_completion_info
}

# 脚本入口点
main "$@"