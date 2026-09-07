# shpoc 🛡️

**Shell Polymorphic Obfuscator in C**

`shpoc` is a high-security polymorphic compiler that wraps interpreted shell scripts (Bash, Sh, Python, etc.) into protected native C binaries. 

Unlike legacy tools (like `shc` or `gzexe`) which leak source code via process monitoring tools (`ps ax`) or create easily breakable self-extracting scripts, `shpoc` leverages modern Linux kernel features to execute your code natively in RAM, ensuring maximum intellectual property protection.

---

## ✨ Features

* **Polymorphic Ciphers**: Generates a completely unique, randomized multi-byte XOR key array for every single compilation. No two compiled binaries look alike.
* **Dynamic File Size**: Automatically injects random junk padding bytes into the binary structure. Compiling the exact same script multiple times will output files with different hashes (SHA256) and completely different sizes.
* **Zero Process Leaks**: Completely immune to `ps ax`, `ps aux`, or `top` monitoring. Process viewers only see the generic interpreter path mapping a dynamic descriptor.
* **Full STDIN & Pipe Support**: Powered by `memfd_create()`, the generated binary keeps the standard input channel completely unrestricted. Commands like `echo "data" | ./binary` work flawlessly.
* **Seamless Argument Forwarding**: Transparently passes flags, options, and parameters (`$1`, `$2`, etc.) straight into your inner script without breaking syntaxes.
* **Native Environment Integrity**: Automatically resolves absolute paths and injects a custom `$_0` variable back to the inner runtime, allowing script-level hybrid privilege elevation (`sudo`) and self-execution workflows.

---

## 🚀 How it Works (Under the Hood)

1. **Compilation Time**: `shpoc` parses your source script shebang, creates a dynamic encryption key array, and obfuscates the entire shell code via cyclic multi-byte XOR. It embeds this scrambled matrix along with dynamic code instructions into a temporary local `.c` source file, then compiles it using `gcc -O2`.
2. **Execution Time**: When your compiled binary launches, it stays strictly inside the RAM environment. It decrypts the structure onto an anonymous file descriptor created via `memfd_create()`. It then invokes the proper interpreter via a safe `fork() + execvp()` routine pointing to `/dev/fd/X`, completely bypassing physical disk footprints and locking out terminal spying vectors.

---

## 🧭 Handling Script Self-Execution & Local Paths

Because `shpoc` executes your script straight from an anonymous RAM descriptor, the native Bash variable `$0` will always return a virtual path like `/dev/fd/3`. 

To prevent your script from breaking when it needs to resolve its true location on the physical disk (such as self-executing via `sudo` or fetching neighboring configuration files), `shpoc` automatically resolves the binary's absolute path and injects it into a custom environment variable named **`$_0`**.

### 1. Hybrid Privilege Elevation (Sudo)
If your script runs as a regular user but needs to call itself back with `sudo` to elevate privileges dynamically, replace `$0` with `"$_0"`:

```bash
# Old way (Will FAIL inside shpoc because /dev/fd/3 cannot be re-executed by sudo)
# exec sudo \$0 "\$@"

# New secure way (Works FLAWLESSLY)
if [ "\$EUID" -ne 0 ]; then
    echo "[*] Privilege elevation required. Re-launching under sudo..."
    exec sudo "\$_0" "$@"
fi
```

### 2. Accessing Neighboring Files
If your application depends on config assets stored right next to the compiled binary executable, use `dirname` on top of `"$_0"` to safely pinpoint the directory:

```bash
# Get the absolute installation folder dynamically
BASE_DIR=\(dirname "\$_0"\)

# Safely fetch your configurations or dependencies
source "\$BASE_DIR/functions.sh"
cat "\$BASE_DIR/settings.conf"
```

---

## 🛠️ Requirements

* Linux Kernel 3.17 or newer (for `memfd_create` support).
* GCC Compiler (`sudo apt install gcc` or equivalent).

---

## 💻 Usage

### 1. Installation
Simply clone or copy the `shpoc` automation utility into your system:
```bash
git clone https://github.com
cd shpoc
chmod +x shpoc
```

### 2. Basic Compilation
To obfuscate and compile a shell script:
```bash
./shpoc <source_script.sh> <output_binary_name>
```

**Example:**
```bash
./shpoc your_scripts.sh your_script
```

### 3. Verification
Test if your compiled application safely processes standard pipelines, interactive keyboard inputs, and command-line arguments using the provided test script:

```bash
# Compile the test script using shpoc
./shpoc test_shpoc.sh my_test_binary

# Run Test A: Verify Pipe Data (Stdin) + Argument Forwarding
echo "Hello World from Pipe" | ./my_test_binary --debug --verbose

# Run Test B: Verify Interactive Keyboard Input + Arguments
./my_test_binary arg1 arg2
```

Check process tracking fields concurrently using another terminal instance while the binary runs:
```bash
ps ax | grep my_test_binary
```
*You will witness that your background threads execute safely, and no internal logic, variables, or critical paths leak into the system process log.*

---

## 📄 License

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
