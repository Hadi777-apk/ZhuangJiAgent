using System.Globalization;
using System.Windows;
using System.Windows.Data;

namespace ZhuangJiAgent.Converters;

/// <summary>
/// 空值转可见性转换器
/// </summary>
public sealed class NullToVisibilityConverter : IValueConverter
{
    public object Convert(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        return value is null || (value is string str && string.IsNullOrWhiteSpace(str))
            ? Visibility.Collapsed
            : Visibility.Visible;
    }

    public object ConvertBack(object? value, Type targetType, object? parameter, CultureInfo culture)
    {
        throw new NotSupportedException();
    }
}
