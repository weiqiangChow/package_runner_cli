use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::fs;
use std::io;
use std::path::Path;
use std::process::{Command, Stdio};

#[derive(Debug, Deserialize, Serialize)]
struct PackageJson {
    scripts: Option<HashMap<String, String>>,
}

fn main() {
    // 检查命令行参数
    let args: Vec<String> = std::env::args().collect();
    
    // 如果包含 --uninstall 参数，执行卸载
    if args.len() > 1 && (args[1] == "--uninstall" || args[1] == "-u") {
        if let Err(e) = uninstall() {
            eprintln!("错误: 卸载失败: {}", e);
            std::process::exit(1);
        }
        return;
    }
    
    // 如果包含 --help 或 -h，显示帮助信息
    if args.len() > 1 && (args[1] == "--help" || args[1] == "-h") {
        show_help();
        return;
    }
    
    let package_json_path = Path::new("package.json");
    
    if !package_json_path.exists() {
        eprintln!("错误: 当前目录下未找到 package.json 文件");
        std::process::exit(1);
    }

    let package_json_content = match fs::read_to_string(package_json_path) {
        Ok(content) => content,
        Err(e) => {
            eprintln!("错误: 无法读取 package.json 文件: {}", e);
            std::process::exit(1);
        }
    };

    let package_json: PackageJson = match serde_json::from_str(&package_json_content) {
        Ok(json) => json,
        Err(e) => {
            eprintln!("错误: 无法解析 package.json 文件: {}", e);
            std::process::exit(1);
        }
    };

    let scripts = match package_json.scripts {
        Some(scripts) => scripts,
        None => {
            eprintln!("错误: package.json 中没有找到 scripts 字段");
            std::process::exit(1);
        }
    };

    if scripts.is_empty() {
        eprintln!("错误: package.json 中没有可用的 scripts");
        std::process::exit(1);
    }

    // 将 scripts 转换为有序的 Vec
    let mut script_list: Vec<(String, String)> = scripts.into_iter().collect();
    script_list.sort_by(|a, b| a.0.cmp(&b.0));

    // 使用 inquire 进行交互式选择
    let options: Vec<String> = script_list
        .iter()
        .map(|(name, cmd)| format!("{}: {}", name, cmd))
        .collect();

    let selection = match inquire::Select::new("请选择要运行的 script:", options.clone())
        .with_page_size(10)
        .prompt()
    {
        Ok(choice) => choice,
        Err(e) => {
            eprintln!("错误: 选择失败: {}", e);
            std::process::exit(1);
        }
    };

    // 从选择中提取 script 名称
    let script_name = script_list
        .iter()
        .find(|(name, cmd)| format!("{}: {}", name, cmd) == selection)
        .map(|(name, _)| name.clone())
        .expect("无法找到选中的 script");

    println!("\n正在运行: {}", script_name);
    println!("命令: {}\n", selection);

    // 运行 script
    if let Err(e) = run_script(&script_name) {
        eprintln!("错误: 运行 script 失败: {}", e);
        std::process::exit(1);
    }
}

fn run_script(script_name: &str) -> io::Result<()> {
    // 检测 npm 或 yarn 是否可用
    let package_manager = detect_package_manager();

    let mut command = match package_manager.as_str() {
        "yarn" => {
            let mut cmd = Command::new("yarn");
            cmd.arg("run").arg(script_name);
            cmd
        }
        "npm" => {
            let mut cmd = Command::new("npm");
            cmd.arg("run").arg(script_name);
            cmd
        }
        _ => {
            // 默认使用 npm
            let mut cmd = Command::new("npm");
            cmd.arg("run").arg(script_name);
            cmd
        }
    };

    command
        .stdin(Stdio::inherit())
        .stdout(Stdio::inherit())
        .stderr(Stdio::inherit());

    let status = command.status()?;

    if !status.success() {
        std::process::exit(status.code().unwrap_or(1));
    }

    Ok(())
}

fn detect_package_manager() -> String {
    // 优先检测 yarn
    if which::which("yarn").is_ok() {
        return "yarn".to_string();
    }

    // 然后检测 npm
    if which::which("npm").is_ok() {
        return "npm".to_string();
    }

    // 如果都找不到，返回 npm（让系统报错）
    "npm".to_string()
}

fn uninstall() -> io::Result<()> {
    println!("🗑️  正在卸载 rps...");
    
    // 获取当前可执行文件的路径
    let current_exe = std::env::current_exe()?;
    let binary_path = current_exe.as_path();
    
    println!("   找到安装位置: {:?}", binary_path);
    
    // 检查是否在标准安装位置
    let is_system_install = binary_path.starts_with("/usr/local/bin") 
        || binary_path.starts_with("/opt/homebrew/bin")
        || binary_path.to_string_lossy().contains(".cargo/bin");
    
    if !is_system_install {
        println!("⚠️  警告: 当前文件不在标准安装位置");
        println!("   位置: {:?}", binary_path);
        print!("   是否仍要继续卸载? (y/N): ");
        use std::io::Write;
        io::stdout().flush()?;
        
        let mut input = String::new();
        io::stdin().read_line(&mut input)?;
        
        if !input.trim().eq_ignore_ascii_case("y") {
            println!("❌ 取消卸载");
            return Ok(());
        }
    }
    
    // macOS 特定：尝试使用 pkgutil 卸载
    #[cfg(target_os = "macos")]
    {
        let pkg_id = "com.package-runner-cli.rps";
        
        // 检查是否有安装记录
        let check_output = Command::new("pkgutil")
            .args(&["--pkgs"])
            .output();
        
        if let Ok(output) = check_output {
            let packages = String::from_utf8_lossy(&output.stdout);
            if packages.contains(pkg_id) {
                println!("📋 找到安装包记录，正在清理...");
                
                // 获取安装的文件列表
                let files_output = Command::new("pkgutil")
                    .args(&["--files", pkg_id])
                    .output();
                
                if let Ok(files_output) = files_output {
                    let files = String::from_utf8_lossy(&files_output.stdout);
                    for file in files.lines() {
                        let file_path = format!("/{}", file);
                        if Path::new(&file_path).exists() {
                            println!("   删除: {}", file_path);
                            let _ = fs::remove_file(&file_path);
                        }
                    }
                }
                
                // 删除安装记录
                let _ = Command::new("pkgutil")
                    .args(&["--forget", pkg_id])
                    .output();
                
                println!("✅ 已清理安装记录");
            }
        }
    }
    
    // 删除当前可执行文件
    // 注意：在 Unix 系统上，正在运行的程序无法删除自己
    println!("🗑️  正在删除二进制文件...");
    
    #[cfg(unix)]
    {
        // 检查是否需要 sudo 权限
        let needs_sudo = binary_path.starts_with("/usr/local/bin") 
            || binary_path.starts_with("/usr/bin")
            || binary_path.starts_with("/opt");
        
        if needs_sudo {
            println!("⚠️  需要管理员权限来删除系统文件");
            println!("   正在尝试使用 sudo 删除...");
            
            // 使用 sudo 删除文件
            let status = Command::new("sudo")
                .arg("rm")
                .arg("-f")
                .arg(binary_path)
                .status();
            
            match status {
                Ok(s) if s.success() => {
                    println!("✅ 文件已删除");
                }
                Ok(_) => {
                    println!("❌ 删除失败，可能需要输入密码");
                    println!("💡 请手动运行: sudo rm {}", binary_path.display());
                    return Ok(());
                }
                Err(_) => {
                    println!("❌ 无法执行 sudo 命令");
                    println!("💡 请手动运行: sudo rm {}", binary_path.display());
                    return Ok(());
                }
            }
        } else {
            // 对于用户目录下的文件，尝试直接删除
            // 如果失败，使用临时脚本在程序退出后删除
            match fs::remove_file(binary_path) {
                Ok(_) => {
                    println!("✅ 文件已删除");
                }
                Err(_) => {
                    // 创建临时删除脚本（程序退出后执行）
                    let temp_script = format!("/tmp/rps_uninstall_{}.sh", std::process::id());
                    let script_content = format!(
                        "#!/bin/bash\nsleep 1\nrm -f \"{}\"\nrm -f \"$0\"\n",
                        binary_path.display()
                    );
                    
                    if fs::write(&temp_script, script_content).is_ok() {
                        use std::os::unix::fs::PermissionsExt;
                        if let Ok(perms) = fs::metadata(&temp_script) {
                            let mut p = perms.permissions();
                            p.set_mode(0o755);
                            let _ = fs::set_permissions(&temp_script, p);
                        }
                        
                        let _ = Command::new("sh")
                            .arg(&temp_script)
                            .spawn();
                        
                        println!("✅ 卸载完成！文件将在程序退出后删除");
                    } else {
                        println!("⚠️  无法创建删除脚本");
                        println!("💡 请手动删除: {}", binary_path.display());
                    }
                }
            }
        }
        
        println!("💡 请关闭当前终端窗口或重新打开终端以使更改生效");
    }
    
    #[cfg(windows)]
    {
        // Windows 上可以直接删除
        match fs::remove_file(binary_path) {
            Ok(_) => println!("✅ 卸载完成！"),
            Err(e) => {
                println!("❌ 删除失败: {}", e);
                println!("💡 请手动删除文件或使用卸载程序");
            }
        }
    }
    
    Ok(())
}

fn show_help() {
    println!("rps - Run Package Scripts");
    println!();
    println!("用法:");
    println!("  rps                在包含 package.json 的目录下运行，交互式选择并运行 script");
    println!("  rps --uninstall    卸载 rps 命令");
    println!("  rps --help         显示此帮助信息");
    println!();
    println!("示例:");
    println!("  cd /path/to/project");
    println!("  rps");
    println!();
    println!("卸载:");
    println!("  rps --uninstall");
}

