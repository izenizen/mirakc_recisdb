# --- ステージ1: ビルド環境 (builder) ---
FROM debian:bookworm-slim AS builder

RUN apt-get update && apt-get install -y \
    build-essential git libpcsclite-dev pkg-config autoconf automake libtool \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp

# 1. libyakisoba のビルド
RUN git clone https://github.com/tsunoda14/libyakisoba.git /tmp/libyakisoba
COPY ./bcas_keys /tmp/libyakisoba/src/bcas_keys
RUN cd /tmp/libyakisoba && autoreconf -i && ./configure && make

# 2. libsobacas のビルド
RUN git clone https://github.com/tsunoda14/libsobacas.git /tmp/libsobacas
RUN cd /tmp/libsobacas && autoreconf -i && \
    CPPFLAGS="-I/tmp/libyakisoba/src" LDFLAGS="-L/tmp/libyakisoba/src/.libs" ./configure && \
    make

# --- ステージ2: 実行環境 ---
FROM mirakc/mirakc:3.4.68-debian

USER root

# 1. 実行に必要なパッケージのインストール
RUN apt-get update && apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        ca-certificates libpcsclite1 pcscd libccid pcsc-tools dvb-tools wget \
    && \
    # 2. recisdb のインストール (バージョンは適宜調整してください)
    wget https://github.com/kazuki0824/recisdb-rs/releases/download/1.2.4/recisdb_1.2.4-1_amd64.deb && \
    apt-get install -y ./recisdb_1.2.4-1_amd64.deb && \
    rm -f ./recisdb_1.2.4-1_amd64.deb && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 3. ビルド成果物のコピー (重要: 両方のライブラリが必要)
COPY --from=builder /tmp/libyakisoba/src/.libs/libyakisoba.so* /usr/local/lib/
COPY --from=builder /tmp/libsobacas/.libs/libsobacas.so* /usr/local/lib/
# 【最重要】鍵ファイルをライブラリが探すパス（sysconfdir）に合わせて配置
# デフォルトの prefix が /usr/local の場合、etc はここになります
RUN mkdir -p /usr/local/etc
COPY ./bcas_keys /usr/local/etc/bcas_keys

# または、環境変数でパスを明示的に指定する（これが最も確実です）
ENV BCAS_KEYS_FILE=/usr/local/etc/bcas_keys
# ライブラリキャッシュの更新 (これを行わないと .so を認識できません)
RUN ldconfig

# 4. 起動スクリプトの配置 (LD_PRELOAD を設定する前に行う)
WORKDIR /app
COPY ./container-init.sh ./container-init.sh
RUN chmod +x ./container-init.sh

# 5. 環境変数の設定 (ここで行えばビルド中の RUN には影響しません)
ENV LD_PRELOAD=/usr/local/lib/libsobacas.so

ENTRYPOINT ["./container-init.sh"]

