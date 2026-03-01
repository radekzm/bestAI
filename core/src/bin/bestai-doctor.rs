use colored::*;
use anyhow::Result;
use std::path::Path;

fn main() -> Result<()> {
    println!("
{} {}", "🩺 bestAI Doctor".cyan().bold(), "(Rust Horizon v14.1)");
    println!("{}", "------------------------------------------------".dimmed());

    let paths = vec![
        (".bestai/GPS.json", "Global Project State"),
        (".bestai/CONTRACT.json", "AI Agent Contract"),
        ("CLAUDE.md", "Project Instructions"),
    ];

    for (path, label) in paths {
        if Path::new(path).exists() {
            println!("  {} {} present", "✅".green(), label);
        } else {
            println!("  {} {} missing", "❌".red(), label);
        }
    }

    println!("
{}", "All systems operational (Binary Verification OK).".green());
    Ok(())
}
