FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    openjdk-8-jdk \
    libxtc-rats-java \
    git \
    gcc \
    cpp \
    curl \
    make \
    clisp \
    indent \
    && apt-get clean

ENV JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
ENV PATH="${JAVA_HOME}/bin:${PATH}"

# SuperC (xtc含む) をクローン
WORKDIR /opt
RUN git clone --depth=1 https://github.com/appleseedlab/superc.git

# CLASSPATHを設定
ENV CLASSPATH="/opt/superc/classes:/usr/share/java/rats-runtime.jar:/usr/share/java/rats.jar"

# sc-tascellをクローンしてc2scppをビルド
RUN git clone https://github.com/tascell/sc-tascell.git /opt/sc-tascell
WORKDIR /opt/sc-tascell/src/c2scpp
RUN ./configure && make

# sc2c環境変数
ENV SC_PREFIX=/opt/sc-tascell
ENV SC_PATH=/opt/sc-tascell/bin
ENV SC_CMDLINE=/opt/sc-tascell/src/sc-cmdline.lsp
ENV SC_LISP=clisp
ENV SC_LISP_PATH=/usr/bin/clisp
ENV PATH="/opt/sc-tascell/bin:${PATH}"

# パーサのソースをコピーしてビルド
WORKDIR /workspace/src
COPY src/TascellC.rats .
COPY src/SCParser.rats .
COPY src/Main.java .
COPY src/SCMain.java .

RUN java xtc.parser.Rats TascellC.rats && \
    java xtc.parser.Rats SCParser.rats && \
    javac -cp $CLASSPATH:. TascellC.java Main.java && \
    javac -cp $CLASSPATH:. SCParser.java SCMain.java

WORKDIR /workspace
CMD ["/bin/bash"]
