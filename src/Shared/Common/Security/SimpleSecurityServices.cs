namespace Shared.Common.Security
{
    /// <summary>
    /// Simple security services for basic operations
    /// </summary>
    public static class SimpleSecurityServices
    {
        /// <summary>
        /// Basic PII masking for demonstration
        /// </summary>
        public static string MaskPII(string data)
        {
            if (string.IsNullOrEmpty(data))
                return string.Empty;

            if (data.Length <= 4)
                return new string('*', data.Length);

            return data.Substring(0, 2) + new string('*', data.Length - 4) + data.Substring(data.Length - 2);
        }
    }
}