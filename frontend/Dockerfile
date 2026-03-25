FROM node:22.14-alpine AS builder

WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime

RUN addgroup -S feedforge && adduser -S feedforge -G feedforge

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=builder /app/dist /usr/share/nginx/html

RUN chown -R feedforge:feedforge /var/cache/nginx /var/log/nginx /run \
    && touch /run/nginx.pid && chown feedforge:feedforge /run/nginx.pid

USER feedforge
EXPOSE 8080

CMD ["nginx", "-g", "daemon off;"]
