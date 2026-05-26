#define _GNU_SOURCE

#include <ctype.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <pthread.h>
#include <signal.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>

#define BYTES_PER_MB ((size_t)1024 * 1024)

static atomic_int running = 1;

typedef struct {
    size_t mem_mb;
} memory_arg_t;

static void handle_signal(int sig) {
    (void)sig;
    atomic_store(&running, 0);
}

static int only_trailing_space(const char *text) {
    while (*text) {
        if (!isspace((unsigned char)*text)) {
            return 0;
        }
        text++;
    }
    return 1;
}

static int parse_int_arg(const char *name, const char *text, int min_value, int max_value, int *out) {
    char *end = NULL;

    errno = 0;
    long value = strtol(text, &end, 10);
    if (errno == ERANGE || end == text || !only_trailing_space(end) ||
        value < min_value || value > max_value) {
        fprintf(stderr,
                "Valor inválido para %s: '%s' (esperado inteiro entre %d e %d)\n",
                name,
                text,
                min_value,
                max_value);
        return 0;
    }

    *out = (int)value;
    return 1;
}

static int parse_size_arg(const char *name, const char *text, size_t max_value, size_t *out) {
    char *end = NULL;

    if (text[0] == '-') {
        fprintf(stderr,
                "Valor inválido para %s: '%s' (esperado inteiro entre 0 e %zu)\n",
                name,
                text,
                max_value);
        return 0;
    }

    errno = 0;
    unsigned long long value = strtoull(text, &end, 10);
    if (errno == ERANGE || end == text || !only_trailing_space(end) ||
        value > (unsigned long long)max_value) {
        fprintf(stderr,
                "Valor inválido para %s: '%s' (esperado inteiro entre 0 e %zu)\n",
                name,
                text,
                max_value);
        return 0;
    }

    *out = (size_t)value;
    return 1;
}

static double monotonic_seconds(void) {
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (double)ts.tv_sec + (double)ts.tv_nsec / 1e9;
}

static double read_uptime_seconds(void) {
    FILE *f = fopen("/proc/uptime", "r");
    if (!f) return -1.0;

    double uptime = -1.0;
    if (fscanf(f, "%lf", &uptime) != 1) {
        uptime = -1.0;
    }
    fclose(f);
    return uptime;
}

static long read_long_from_file(const char *path) {
    FILE *f = fopen(path, "r");
    if (!f) return -1;

    long value = -1;
    if (fscanf(f, "%ld", &value) != 1) {
        value = -1;
    }
    fclose(f);
    return value;
}

static double read_cpu_temp_celsius(void) {
    long milli_celsius = read_long_from_file("/sys/class/thermal/thermal_zone0/temp");
    if (milli_celsius < 0) return -1.0;
    return (double)milli_celsius / 1000.0;
}

static long read_cpu_freq_khz(void) {
    long freq = read_long_from_file("/sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq");
    if (freq < 0) {
        freq = read_long_from_file("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq");
    }
    return freq;
}

static int read_throttled_status(unsigned long *value) {
    FILE *fp = popen("vcgencmd get_throttled 2>/dev/null", "r");
    if (!fp) return 0;

    char buffer[128];
    int ok = 0;
    if (fgets(buffer, sizeof(buffer), fp)) {
        char *eq = strchr(buffer, '=');
        if (eq) {
            char *end = NULL;
            errno = 0;
            unsigned long parsed = strtoul(eq + 1, &end, 0);
            if (errno == 0 && end != eq + 1 && only_trailing_space(end)) {
                *value = parsed;
                ok = 1;
            }
        }
    }

    pclose(fp);
    return ok;
}

static void iso_datetime_now(char *buffer, size_t size) {
    time_t now = time(NULL);
    struct tm tm_now;
    localtime_r(&now, &tm_now);
    strftime(buffer, size, "%Y-%m-%d %H:%M:%S", &tm_now);
}

static void read_meminfo(long *mem_total_kb, long *mem_available_kb, long *swap_free_kb) {
    *mem_total_kb = -1;
    *mem_available_kb = -1;
    *swap_free_kb = -1;

    FILE *f = fopen("/proc/meminfo", "r");
    if (!f) return;

    char key[64];
    long value = 0;
    char unit[32];

    while (fscanf(f, "%63[^:]: %ld %31s\n", key, &value, unit) == 3) {
        if (strcmp(key, "MemTotal") == 0) {
            *mem_total_kb = value;
        } else if (strcmp(key, "MemAvailable") == 0) {
            *mem_available_kb = value;
        } else if (strcmp(key, "SwapFree") == 0) {
            *swap_free_kb = value;
        }
    }

    fclose(f);
}

static void *cpu_worker(void *arg) {
    unsigned long id = (unsigned long)(uintptr_t)arg;
    volatile double x = 0.123456789 + (double)id;

    while (atomic_load(&running)) {
        for (int i = 0; i < 100000; i++) {
            x += sin(x) * sqrt(fabs(x) + 1.0);
            if (x > 1000000.0 || x < -1000000.0 || isnan(x)) {
                x = 0.123456789 + (double)id;
            }
        }
    }

    return NULL;
}

static void *memory_worker(void *arg) {
    memory_arg_t *mem_arg = (memory_arg_t *)arg;
    size_t total_bytes = mem_arg->mem_mb * BYTES_PER_MB;

    if (total_bytes == 0) {
        return NULL;
    }

    unsigned char *buffer = NULL;
    int rc = posix_memalign((void **)&buffer, 4096, total_bytes);
    if (rc != 0 || !buffer) {
        fprintf(stderr, "Erro ao alocar %zu MB de memória: %s\n", mem_arg->mem_mb, strerror(rc));
        return NULL;
    }

    memset(buffer, 0, total_bytes);

    volatile unsigned long long checksum = 0;

    while (atomic_load(&running)) {
        for (size_t i = 0; i < total_bytes; i += 64) {
            unsigned char value = (unsigned char)(buffer[i] + 1u + (unsigned char)(i & 0xFFu));
            buffer[i] = value;
            checksum += value;
        }
    }

    /* Evita que o compilador remova completamente o laço. */
    if (checksum == 0xFFFFFFFFFFFFFFFFULL) {
        fprintf(stderr, "checksum raro: %llu\n", checksum);
    }

    free(buffer);
    return NULL;
}

static int sync_log_fd(int fd, const char *context) {
    if (fsync(fd) != 0) {
        fprintf(stderr, "Erro ao sincronizar %s: %s\n", context, strerror(errno));
        return -1;
    }

    return 0;
}

static int write_csv_header(int fd) {
    if (dprintf(fd,
                "epoch_s,datetime,elapsed_s,uptime_s,temp_c,load1,load5,load15,cpu_khz,throttled,mem_total_kb,mem_available_kb,swap_free_kb\n") < 0) {
        fprintf(stderr, "Erro ao escrever cabeçalho do log: %s\n", strerror(errno));
        return -1;
    }

    return sync_log_fd(fd, "cabeçalho do log");
}

static int write_log_line(int fd, double start_monotonic) {
    char datetime[64];
    char throttled_text[32] = "NA";

    time_t epoch = time(NULL);
    double elapsed = monotonic_seconds() - start_monotonic;
    double uptime = read_uptime_seconds();
    double temp_c = read_cpu_temp_celsius();
    long cpu_khz = read_cpu_freq_khz();

    double loadavg[3] = {-1.0, -1.0, -1.0};
    getloadavg(loadavg, 3);

    unsigned long throttled = 0;
    if (read_throttled_status(&throttled)) {
        snprintf(throttled_text, sizeof(throttled_text), "0x%lx", throttled);
    }

    long mem_total_kb, mem_available_kb, swap_free_kb;
    read_meminfo(&mem_total_kb, &mem_available_kb, &swap_free_kb);

    iso_datetime_now(datetime, sizeof(datetime));

    if (dprintf(
        fd,
        "%ld,%s,%.0f,%.0f,%.2f,%.2f,%.2f,%.2f,%ld,%s,%ld,%ld,%ld\n",
        (long)epoch,
        datetime,
        elapsed,
        uptime,
        temp_c,
        loadavg[0],
        loadavg[1],
        loadavg[2],
        cpu_khz,
        throttled_text,
        mem_total_kb,
        mem_available_kb,
        swap_free_kb
    ) < 0) {
        fprintf(stderr, "Erro ao escrever linha de log: %s\n", strerror(errno));
        return -1;
    }

    return sync_log_fd(fd, "linha de log");
}

static void usage(const char *prog) {
    fprintf(stderr,
            "Uso: %s <log.csv> <intervalo_s> <cpu_threads> <mem_mb>\n"
            "Exemplo: %s logs/teste.csv 30 4 1024\n\n"
            "Campos:\n"
            "  log.csv       caminho do arquivo CSV\n"
            "  intervalo_s   intervalo entre registros do log\n"
            "  cpu_threads   threads de estresse de CPU; use 0 para desativar\n"
            "  mem_mb        memória em MB para estresse; use 0 para desativar\n",
            prog, prog);
}

int main(int argc, char *argv[]) {
    if (argc != 5) {
        usage(argv[0]);
        return 2;
    }

    const char *log_path = argv[1];
    int interval_seconds = 0;
    int cpu_threads = 0;
    size_t mem_mb = 0;

    if (!parse_int_arg("intervalo_s", argv[2], 1, INT_MAX, &interval_seconds) ||
        !parse_int_arg("cpu_threads", argv[3], 0, INT_MAX, &cpu_threads) ||
        !parse_size_arg("mem_mb", argv[4], SIZE_MAX / BYTES_PER_MB, &mem_mb)) {
        usage(argv[0]);
        return 2;
    }

    signal(SIGINT, handle_signal);
    signal(SIGTERM, handle_signal);

    int fd = open(log_path, O_WRONLY | O_CREAT | O_APPEND, 0644);
    if (fd < 0) {
        perror("Erro ao abrir arquivo de log");
        return 1;
    }

    struct stat st;
    if (fstat(fd, &st) != 0) {
        perror("Erro ao consultar arquivo de log");
        close(fd);
        return 1;
    }

    if (st.st_size == 0 && write_csv_header(fd) != 0) {
        close(fd);
        return 1;
    }

    int exit_code = 0;
    pthread_t *cpu = NULL;
    if (cpu_threads > 0) {
        cpu = calloc((size_t)cpu_threads, sizeof(pthread_t));
        if (!cpu) {
            perror("Erro ao alocar vetor de threads CPU");
            close(fd);
            return 1;
        }

        for (int i = 0; i < cpu_threads; i++) {
            int rc = pthread_create(&cpu[i], NULL, cpu_worker, (void *)(uintptr_t)i);
            if (rc != 0) {
                fprintf(stderr, "Erro ao criar thread CPU %d: %s\n", i, strerror(rc));
                atomic_store(&running, 0);
                cpu_threads = i;
                exit_code = 1;
                break;
            }
        }
    }

    pthread_t mem_thread;
    int mem_thread_started = 0;
    memory_arg_t mem_arg = {.mem_mb = mem_mb};
    if (mem_mb > 0) {
        int rc = pthread_create(&mem_thread, NULL, memory_worker, &mem_arg);
        if (rc != 0) {
            fprintf(stderr, "Erro ao criar thread de memória: %s\n", strerror(rc));
        } else {
            mem_thread_started = 1;
        }
    }

    printf("battery_logger iniciado\n");
    printf("log=%s intervalo=%d cpu_threads=%d mem_mb=%zu\n", log_path, interval_seconds, cpu_threads, mem_mb);
    fflush(stdout);

    double start_monotonic = monotonic_seconds();

    while (atomic_load(&running)) {
        if (write_log_line(fd, start_monotonic) != 0) {
            atomic_store(&running, 0);
            exit_code = 1;
            break;
        }
        sleep((unsigned int)interval_seconds);
    }

    if (cpu) {
        for (int i = 0; i < cpu_threads; i++) {
            pthread_join(cpu[i], NULL);
        }
        free(cpu);
    }

    if (mem_thread_started) {
        pthread_join(mem_thread, NULL);
    }

    if (exit_code == 0 && write_log_line(fd, start_monotonic) != 0) {
        exit_code = 1;
    }

    if (close(fd) != 0) {
        perror("Erro ao fechar arquivo de log");
        exit_code = 1;
    }

    printf("battery_logger encerrado\n");
    return exit_code;
}
