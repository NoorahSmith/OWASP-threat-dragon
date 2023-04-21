ARG         NODE_VERSION=18

# The base image with updates applied
FROM        node:$NODE_VERSION-alpine as base-node
RUN         apk -U upgrade
WORKDIR     /app
RUN         npm i -g npm@latest pnpm
RUN         mkdir -p td.server td.vue
RUN         chown -R node:node /app
USER        node


# Build the front and back-end.  This needs devDependencies which do not
# need to be included in the final image
FROM        base-node as build
RUN         mkdir boms

COPY        pnpm_workspace.yaml pnpm-lock.yaml package.json /app/
COPY        ./td.server/pnpm-lock.yaml ./td.server/package.json ./td.server/
COPY        ./td.vue/pnpm-lock.yaml ./td.vue/package.json ./td.vue/

COPY        ./td.server/.babelrc ./td.server/
COPY        ./td.server/src/ ./td.server/src/
COPY        ./td.vue/src/ ./td.vue/src/
COPY        ./td.vue/public/ ./td.vue/public/
COPY        ./td.vue/*.config.js ./td.vue/

RUN         pnpm install -r --frozen-lockfile
RUN         npm run build

# Build the final, production image. 
FROM        base-node
COPY        ./td.server/package*.json ./td.server/pnpm-lock.yaml ./td.server/
RUN         cd td.server && pnpm install --prod --frozen-lockfile --ignore-scripts
COPY        --from=build /app/td.server/dist ./td.server/dist
COPY        --from=build /app/td.vue/dist ./dist
COPY        ./td.server/index.js ./td.server/index.js

HEALTHCHECK --interval=10s --timeout=2s --start-period=2s CMD ["/nodejs/bin/node", "./td.server/dist/healthcheck.js"]
CMD         ["td.server/index.js"]
