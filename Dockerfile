################################################################################
# 1. 빌드 단계 (Build Stage): JAR 파일 및 레이어 생성
# FROM openjdk:17-jdk-slim-bullseye 또는 openjdk:17-jdk-slim 등을 사용할 수 있습니다.
################################################################################
FROM openjdk:17-jdk-slim AS build

# 작업 디렉토리 설정
WORKDIR /app

# Gradle Wrapper, 설정 파일 복사
COPY gradlew .
COPY gradle gradle
COPY build.gradle settings.gradle ./

# 소스 코드 복사 및 빌드 실행 (bootJar 태스크 실행)
# ./gradlew bootJar 명령은 애플리케이션 JAR와 함께 라이브러리 JAR도 생성합니다.
COPY src src
RUN ./gradlew bootJar --no-daemon

# Spring Boot의 레이어 분리 기능을 사용하여 최적화된 레이어를 추출합니다.
# RUN java -Djarmode=layertools -jar build/libs/*.jar extract --destination extracted

################################################################################
# 2. 실행 단계 (Run Stage): JRE만 포함하여 이미지 크기 최소화
# FROM openjdk:17-jre-slim-bullseye 또는 openjdk:17-jre-slim 등을 사용할 수 있습니다.
################################################################################
FROM openjdk:17-jdk-slim AS final

# 📝 보안 설정: 권한 없는 사용자(non-root user)로 실행
# 대부분의 공식 JRE 이미지에는 'nobody' 사용자가 포함되어 있습니다.
RUN groupadd -r spring && useradd -r -g spring spring
USER spring

# 작업 디렉토리를 /app으로 설정 (선택 사항)
WORKDIR /app

# 1단계에서 생성된 애플리케이션 JAR 파일을 복사
# 레이어 분리를 사용하지 않는 경우:
COPY --from=build /app/build/libs/*.jar app.jar

# ----------------------------------------------------------------------
# (대안: 레이어 분리 사용 시)
# 1단계에서 추출한 4개의 Spring Boot 레이어를 순서대로 복사하여 캐싱 효율을 극대화합니다.
# COPY --from=build /app/extracted/dependencies/ ./
# COPY --from=build /app/extracted/spring-boot-loader/ ./
# COPY --from=build /app/extracted/snapshot-dependencies/ ./
# COPY --from=build /app/extracted/application/ ./
# ENTRYPOINT ["java", "org.springframework.boot.loader.JarLauncher"]
# ----------------------------------------------------------------------

# 📌 컨테이너 시작 시 실행될 명령 (최종 JAR 실행)
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
