using System.Text.Json;

namespace DevEnvInit.Services;

internal static class JsonElementExtensions
{
    public static JsonElement RequireProperty(this JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out var value))
        {
            throw new InvalidDataException($"Required JSON property '{name}' is missing.");
        }

        return value;
    }

    public static string GetStringOrDefault(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString() ?? string.Empty
            : string.Empty;

    public static string? GetNullableString(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.String
            ? value.GetString()
            : null;

    public static int GetInt32OrDefault(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var result)
            ? result
            : 0;

    public static int? GetNullableInt32(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.Number && value.TryGetInt32(out var result)
            ? result
            : null;

    public static bool GetBooleanOrDefault(this JsonElement element, string name) =>
        element.TryGetProperty(name, out var value) && value.ValueKind == JsonValueKind.True ||
        element.TryGetProperty(name, out value) && value.ValueKind == JsonValueKind.False && value.GetBoolean();

    public static IReadOnlyList<string> GetStringArrayOrEmpty(this JsonElement element, string name)
    {
        if (!element.TryGetProperty(name, out var value) || value.ValueKind != JsonValueKind.Array)
        {
            return Array.Empty<string>();
        }

        return value.EnumerateArray()
            .Where(item => item.ValueKind == JsonValueKind.String)
            .Select(item => item.GetString() ?? string.Empty)
            .Where(item => item.Length > 0)
            .ToArray();
    }
}
