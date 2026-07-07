using System.IO;

namespace ZhuangJiAgent;

/// <summary>
/// 应用路径解析。所有相对路径统一基于 AppContext.BaseDirectory 解析，
/// 避免依赖进程当前工作目录（从开始菜单/快捷方式启动时 CWD 可能是 system32）。
/// 绝对路径原样返回。
/// </summary>
internal static class AppPaths
{
    public static string BaseDirectory { get; } = AppContext.BaseDirectory;

    public static string ResolvePath(string? path)
    {
        if (string.IsNullOrWhiteSpace(path))
            return BaseDirectory;
        return Path.IsPathRooted(path)
            ? path
            : Path.GetFullPath(Path.Combine(BaseDirectory, path));
    }
}
