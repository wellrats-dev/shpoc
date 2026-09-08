#!/bin/bash

# ==============================================================================
#  shpoc - Shell Polymorphic Obfuscator in C
#  Copyright (c) 2026 Wellington Rats <wellrats@gmail.com>
#
#  DESCRIPTION
#
#  shpoc is a powerful polymorphic shell script compiler that wraps 
#  interpreted scripts into protected C binaries. 
#
#  Instead of relying on legacy methods that expose source code via process 
#  monitoring tools, it uses dynamic multi-byte XOR encryption and injects 
#  payload data straight into the interpreter's RAM channel. 
#
#  It randomizes binary signatures and file sizes on every compilation, 
#  preventing static text extraction (via 'strings') and monitoring leaks 
#  (via 'ps ax'), while fully supporting argument forwarding, standard input 
#  pipes (stdin), and hybrid privilege elevation (sudo).
#
#  LICENSE
#
#  This software is dual-licensed under the GNU GPL v3.0 (for open-source
#  projects) or a Commercial License (for proprietary use).
#
#  For commercial licenses, contact: wellrats@gmail.com
#  GPL v3.0 License details: https://www.gnu.org/licenses/gpl-3.0.html
#
#  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#  SOFTWARE.

# Preparation if you use shpoc to compile/ofuscate this source
[ -z "$_0" ] && _0="$0"

# ------------------------------------------------------------------------------

function globals() {

   PROG=$(basename "$_0")
   VERSION="1.0"
   POSITIONAL_ARGS=()
   SOURCE=
   OUTPUT=
   ARG_INSTALL=0

}

# ------------------------------------------------------------------------------

function params() {

   while [[ $# -gt 0 ]] ; do case "$1" in

      -h | --help)                 shift; show_help | more ; shift $#; exit 0 ;;
      -o | --output)               shift; OUTPUT="$1"; shift ;;
      -i | --install)              shift; ARG_INSTALL=1 ;;
      -v | --version)              shift; show_version; shift $#; exit 0 ;;
      -*)                          echo "invalid option: $1, try -h"; shift $#; exit 0 ;;
       *)                          POSITIONAL_ARGS+=("$1"); shift ;;

   esac;done

}

# ------------------------------------------------------------------------------

do_job() {

   do_shpoc "$@" 

}

# ------------------------------------------------------------------------------

show_help() {
   echo \
"Usage: $PROG [options] <file.sh>
Options:
    -o <file>           Place the output binary in the specified file.
    -i | --install      Install the compiled binary to the system after compilation. (sudo required)
    -h | --help         Show this help message and exit.
    -v | --version      Show the version information and exit.

Description

    $PROG is a powerful polymorphic shell script compiler that wraps 
    interpreted scripts into protected C binaries. 

    Instead of relying on legacy methods that expose source code via process 
    monitoring tools, it uses dynamic encryption and injects payload data 
    straight into the interpreter's RAM channel. 

    It randomizes binary signatures and file sizes on every compilation, 
    preventing static text extraction (via 'strings') and monitoring leaks 
    (via 'ps ax'), while fully supporting argument forwarding, standard input 
    pipes (stdin), and hybrid privilege elevation (sudo).

Author

    Wellington Rats <wellrats@gmail.com>
    @wellrats on Instagram and Telegram"
   return 1
}

# ------------------------------------------------------------------------------

log_message() {
    echo "[*] [shpoc] $1"
}

# ------------------------------------------------------------------------------

validations() {

    SOURCE=$1
    if [ -z "$SOURCE" ]; then
        log_message "Error: Source file is not specified."
        exit 1
    fi

    if [ ! -f "$SOURCE" ]; then
        log_message "Error: Source file '$SOURCE' not found."
        exit 1
    fi

    [ -z "${OUTPUT}" ] && OUTPUT="${SOURCE}.out"
}
# ------------------------------------------------------------------------------

do_shpoc() {

    # local OUTPUT="$2"
    local TEMP_C="temp_secure_compiler.c"
    
    if [[ "$SOURCE" != *.sh ]] ; then
       log_message "Renaming ${SOURCE} to ${SOURCE}.sh"
       mv "$SOURCE" "${SOURCE}.sh"
       SOURCE="${SOURCE}.sh"
    fi

    if ! command -v gcc &> /dev/null; then
        log_message "Error: gcc compiler is not installed. Run: sudo apt install gcc"
        return 1
    fi

    # 1. Extract the shebang directly in Bash
    local FIRST_LINE=$(head -n 1 "$SOURCE")
    local INTERPRETER="bash"
    if [[ "$FIRST_LINE" =~ ^\#! ]]; then
        INTERPRETER=$(echo "$FIRST_LINE" | sed -E 's/^\#!//; s/^[[:space:]]*//')
        if [[ "$(basename "${INTERPRETER%% *}")" == "env" ]]; then
            # "#!/usr/bin/env <interpreter> [args...]" -> resolve to the real interpreter
            INTERPRETER=$(echo "$INTERPRETER" | awk '{print $2}')
        else
            INTERPRETER="${INTERPRETER%% *}"
        fi
    fi

    log_message "Interpreter detected: $INTERPRETER"
    log_message "Generating dynamic key array and random padding..."

    # 2. POLYMORPHISM: Dynamic key size (between 16 and 64 bytes)
    local KEY_SIZE=$(( 16 + RANDOM % 49 ))
    local KEY_HEX=""
    local KEY_BYTES=()
    for ((i=0; i<KEY_SIZE; i++)); do
        local BYTE=$(( 1 + RANDOM % 255 ))
        KEY_BYTES+=($BYTE)
        KEY_HEX+="$(printf "0x%02x," $BYTE)"
    done

    # 3. DYNAMIC SIZE: Random padding (between 100 and 2000 bytes)
    local PADDING_SIZE=$(( 100 + RANDOM % 1901 ))
    local PADDING_HEX=""
    for ((i=0; i<PADDING_SIZE; i++)); do
        PADDING_HEX+="$(printf "0x%02x," $(( RANDOM % 256 )))"
    done

    # 4. MULTI-BYTE XOR ENCRYPTION
    local SOURCE_SIZE=$(wc -c < "$SOURCE")
    local HEX_CRYPTODATA=$(od -v -An -t u1 "$SOURCE" | awk -v keys="${KEY_BYTES[*]}" '
        BEGIN {
            split(keys, k, " ")
            key_len = length(k)
            idx = 0
        }
        {
            for (i=1; i<=NF; i++) {
                printf "0x%02x,", xor($i, k[(idx % key_len) + 1])
                idx++
            }
        }
    ')

    log_message "Generating protected C source code with memfd support..."
    cat << EOF > "$TEMP_C"
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/wait.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    // The encrypted script data
    unsigned char crypto_data[] = { ${HEX_CRYPTODATA} 0x00 };
    unsigned int data_len = ${SOURCE_SIZE};

    // The dynamic key array generated on this compilation
    unsigned char xor_key[] = { ${KEY_HEX} 0x00 };
    unsigned int key_len = ${KEY_SIZE};

    // Dynamic padding to randomize file size
    unsigned char junk_padding[] = { ${PADDING_HEX} 0x00 };

    // 1. Decrypt the script in RAM
    for (unsigned int i = 0; i < data_len; i++) {
        crypto_data[i] ^= xor_key[i % key_len];
    }

    // 2. CREATE ANONYMOUS IN-MEMORY FILE (memfd)
    int memfd = memfd_create("shpoc_payload", 0);
    if (memfd < 0) return 1;

    // 3. ABSOLUTE PATH RESOLUTION VIA KERNEL (/proc/self/exe)
    char absolute_self_path[4096];
    ssize_t path_len = readlink("/proc/self/exe", absolute_self_path, sizeof(absolute_self_path) - 1);
    
    if (path_len != -1) {
        absolute_self_path[path_len] = '\0';
    } else {
        if (realpath(argv[0], absolute_self_path) == NULL) {
            strncpy(absolute_self_path, argv[0], sizeof(absolute_self_path) - 1);
            absolute_self_path[sizeof(absolute_self_path) - 1] = '\0';
        }
    }

    // 4. Injects the fully resolved absolute path into the runtime script context
    // NO 'cd' command injected here anymore to respect the user's working directory!
    dprintf(memfd, "_0=\"%s\"\n", absolute_self_path);

    // Write the decrypted script into the anonymous file descriptor with error checking
    if (write(memfd, crypto_data, data_len) < 0) {
        close(memfd);
        return 1;
    }

    // Seek back to the beginning of the file
    lseek(memfd, 0, SEEK_SET);

    // 5. EXECUTE INTERPRETER VIA FORK + EXECVP
    pid_t pid = fork();
    if (pid < 0) {
        close(memfd);
        return 1;
    }

    if (pid == 0) {
        // --- CHILD PROCESS ---
        char memfd_path[64];
        snprintf(memfd_path, sizeof(memfd_path), "/dev/fd/%d", memfd);

        // Build execution arguments
        int exec_argc = argc + 1;
        char **exec_argv = malloc((exec_argc + 1) * sizeof(char *));
        if (!exec_argv) exit(1);
        
        exec_argv[0] = "${INTERPRETER}";
        exec_argv[1] = memfd_path;
        
        // Forward original CLI arguments seamlessly
        for (int i = 1; i < argc; i++) {
            exec_argv[i + 1] = argv[i];
        }
        exec_argv[exec_argc] = NULL;

        execvp(exec_argv[0], exec_argv);
        exit(1);
    }

    // --- PARENT PROCESS ---
    close(memfd);

    int status;
    waitpid(pid, &status, 0);
    return WEXITSTATUS(status);
}
EOF

    log_message "Compiling dynamic protected binary..."
    gcc -O2 "$TEMP_C" -o "$OUTPUT"

    if [ $? -eq 0 ]; then
        log_message "Absolute success! Polymorphic binary generated: $OUTPUT"
        if [ "$ARG_INSTALL" -eq 1 ]; then
            log_message "Installing $OUTPUT to /usr/local/bin..."
            sudo cp "$OUTPUT" /usr/local/bin/
            if [ $? -eq 0 ]; then
                log_message "Installation successful."
            else
                log_message "Installation failed."
            fi
        fi
    else
        log_message "Critical error during compilation."
    fi

    rm -f "$TEMP_C"
}

# ------------------------------------------------------------------------------

show_version() {
echo "$PROG $VERSION ${DESC}"
license
}

# ------------------------------------------------------------------------------

license()  {
cat << EOF
Copyright (c) 2026 Wellington Rats

LICENSE

This software is dual-licensed under the GNU GPL v3.0 (for open-source
projects) or a Commercial License (for proprietary use).

For commercial licenses, contact: wellrats@gmail.com
GPL v3.0 License details: https://www.gnu.org/licenses/gpl-3.0.html

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

}

if [ "${BASH_SOURCE}" = "$0" ]; then

    globals
    params "$@"
    
    set -- "${POSITIONAL_ARGS[@]}"
    
    validations "$@"    
    do_job "$@"

fi

