# 咸鱼之王 Web 助手 —— 多阶段构建（Vue3 + Vite → Nginx 静态站点）
# 用法：放在仓库根目录（与 package.json 同级），然后在飞牛里点「重新部署」。
#
# 说明：这里的 FROM 故意不写镜像站域名前缀，优先复用本机已有的
#       node:20-slim / nginx:1.27-alpine（之前构建成功过，镜像已在本地），
#       这样构建时不需要联网解析镜像仓库，绕开你当前的 DNS 污染问题。
#       如果哪天本地镜像被清理、又必须联网拉取，再把 FROM 改成带镜像站前缀的写法。
#
# 版本标记：plain-from + chmod（文件约 1.4KB，旧的镜像站版是 1.02KB，靠大小即可区分）

FROM node:20-slim AS build
ARG NPM_REGISTRY=https://registry.npmmirror.com
WORKDIR /app
RUN npm install -g pnpm@10.19.0 --registry=${NPM_REGISTRY}
COPY package.json pnpm-lock.yaml ./
RUN pnpm install --frozen-lockfile --registry=${NPM_REGISTRY} \
 || pnpm install --no-frozen-lockfile --registry=${NPM_REGISTRY}
COPY . .
RUN pnpm run build

FROM nginx:1.27-alpine
COPY --from=build /app/dist /usr/share/nginx/html

# 关键修复：源文件从 NAS 解压上传时可能带着 600 权限，nginx 工作进程（nginx 用户）
# 读不到就会返回 403 Forbidden，表现为左上角 logo 裂图、answer.json 加载失败。
RUN chmod -R a+rX /usr/share/nginx/html

COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
