FROM node:10.15.3

WORKDIR /usr/src/nodice
COPY package.json .
COPY yarn.lock .
RUN yarn install
COPY . .

EXPOSE 5001

CMD ["node", "server.js"]
