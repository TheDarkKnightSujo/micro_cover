FROM oven/bun:1.3.14 AS build
WORKDIR /app
COPY package.json bun.lock ./
RUN bun install --frozen-lockfile
COPY . .
# Only public browser settings. Private .env files are excluded by .dockerignore.
ENV VITE_MICROCOVER_ADDRESS=0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0
ENV VITE_EVIDENCE_API_URL=/
RUN bun run check && bun run evidence:check && bun run vite build

FROM oven/bun:1.3.14
WORKDIR /app
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY --from=build /app/services ./services
COPY --from=build /app/src ./src
COPY --from=build /app/docs/evidence/phase4 ./docs/evidence/phase4
COPY services/hosting/contract-abi.json ./contracts/out/MicroCover.sol/MicroCover.json
COPY package.json ./
RUN mkdir -p /root/.ssh && chmod 0700 /root/.ssh && usermod --unlock root
ENV NODE_ENV=production
ENV MICROCOVER_EVIDENCE_HOME=/var/data/microcover
ENV MICROCOVER_EVIDENCE_CONTRACT=0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0
EXPOSE 10000
CMD ["bun", "run", "services/hosting/start.ts"]
