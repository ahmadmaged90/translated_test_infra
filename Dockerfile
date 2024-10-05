FROM node:14
ARG password
ARG username
ARG db_url
ARG redis_url
ARG db_name
ARG redis_host
ENV MYSQL_HOST = $db_url
ENV MYSQL_PORT = 3306
ENV MYSQL_USER = $username
ENV MYSQL_PASSWORD = $password
ENV MYSQL_DATABASE = $db_name
ENV REDIS_HOST = $redis_host
ENV REDIS_PORT =6379
ENV REDIS_URL = $redis_url
WORKDIR /usr/src/app
COPY package*.json ./
RUN npm install
COPY . .
EXPOSE 3000
CMD ["node", "app.js"]