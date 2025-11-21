@description('Azure Monitor and Application Insights resources for Farmers Bank Microservices')

param location string = resourceGroup().location
param environmentName string = 'dev'
param logAnalyticsWorkspaceName string = 'farmers-bank-logs'
param applicationInsightsName string = 'farmers-bank-ai'
param actionGroupName string = 'farmers-bank-alerts'
param alertRuleName string = 'farmers-bank-sla-alert'

// Log Analytics Workspace
resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: '${logAnalyticsWorkspaceName}-${environmentName}'
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 90
    features: {
      enableLogAccessUsingOnlyResourcePermissions: true
    }
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
    CostCenter: 'IT-Banking'
  }
}

// Application Insights
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${applicationInsightsName}-${environmentName}'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalyticsWorkspace.id
    IngestionMode: 'LogAnalytics'
    publicNetworkAccessForIngestion: 'Enabled'
    publicNetworkAccessForQuery: 'Enabled'
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
    CostCenter: 'IT-Banking'
  }
}

// Action Group for Alerts
resource actionGroup 'Microsoft.Insights/actionGroups@2023-01-01' = {
  name: '${actionGroupName}-${environmentName}'
  location: 'Global'
  properties: {
    groupShortName: 'FBAlerts'
    enabled: true
    emailReceivers: [
      {
        name: 'DevTeam'
        emailAddress: 'devteam@farmersbank.com'
        useCommonAlertSchema: true
      }
      {
        name: 'OpsTeam'
        emailAddress: 'operations@farmersbank.com'
        useCommonAlertSchema: true
      }
    ]
    smsReceivers: [
      {
        name: 'OnCall'
        countryCode: '1'
        phoneNumber: '5551234567'
      }
    ]
    webhookReceivers: [
      {
        name: 'TeamsWebhook'
        serviceUri: 'https://farmersbank.webhook.office.com/webhookb2/teams-channel-webhook'
        useCommonAlertSchema: true
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Metric Alert Rules
resource responseTimeAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertRuleName}-response-time-${environmentName}'
  location: 'Global'
  properties: {
    description: 'Alert when average response time exceeds 200ms'
    severity: 2
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ResponseTime'
          metricName: 'requests/duration'
          operator: 'GreaterThan'
          threshold: 200
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Availability Alert
resource availabilityAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertRuleName}-availability-${environmentName}'
  location: 'Global'
  properties: {
    description: 'Alert when availability drops below 99%'
    severity: 1
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'Availability'
          metricName: 'availabilityResults/availabilityPercentage'
          operator: 'LessThan'
          threshold: 99
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Exception Rate Alert
resource exceptionAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: '${alertRuleName}-exceptions-${environmentName}'
  location: 'Global'
  properties: {
    description: 'Alert when exception rate exceeds 5%'
    severity: 2
    enabled: true
    scopes: [
      applicationInsights.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'ExceptionRate'
          metricName: 'exceptions/count'
          operator: 'GreaterThan'
          threshold: 5
          timeAggregation: 'Total'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
    actions: [
      {
        actionGroupId: actionGroup.id
        webHookProperties: {}
      }
    ]
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Log Search Alert for Critical Errors
resource criticalErrorAlert 'Microsoft.Insights/scheduledQueryRules@2023-03-15-preview' = {
  name: '${alertRuleName}-critical-errors-${environmentName}'
  location: location
  properties: {
    description: 'Alert on critical errors in application logs'
    severity: 0
    enabled: true
    scopes: [
      logAnalyticsWorkspace.id
    ]
    evaluationFrequency: 'PT1M'
    windowSize: 'PT5M'
    criteria: {
      allOf: [
        {
          query: 'traces | where severityLevel >= 4 | where message contains "Critical" or message contains "Fatal"'
          timeAggregation: 'Count'
          operator: 'GreaterThan'
          threshold: 0
        }
      ]
    }
    actions: {
      actionGroups: [
        actionGroup.id
      ]
      customProperties: {
        AlertType: 'CriticalError'
        Service: 'FarmersBank'
      }
    }
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Custom Workbooks for Monitoring Dashboards
resource farmersServiceWorkbook 'Microsoft.Insights/workbooks@2022-04-01' = {
  name: guid('farmers-bank-monitoring-workbook-${environmentName}')
  location: location
  kind: 'shared'
  properties: {
    displayName: 'Farmers Bank Services Monitoring Dashboard'
    serializedData: json('''
    {
      "version": "Notebook/1.0",
      "items": [
        {
          "type": 3,
          "content": {
            "version": "KqlItem/1.0",
            "query": "requests\\n| where timestamp > ago(1h)\\n| summarize count() by bin(timestamp, 5m), resultCode\\n| render timechart",
            "size": 0,
            "title": "Request Volume and Status Codes (Last Hour)"
          }
        },
        {
          "type": 3,
          "content": {
            "version": "KqlItem/1.0",
            "query": "requests\\n| where timestamp > ago(1h)\\n| summarize avg(duration) by bin(timestamp, 5m)\\n| render timechart",
            "size": 0,
            "title": "Average Response Time (Last Hour)"
          }
        },
        {
          "type": 3,
          "content": {
            "version": "KqlItem/1.0",
            "query": "exceptions\\n| where timestamp > ago(24h)\\n| summarize count() by type, bin(timestamp, 1h)\\n| render barchart",
            "size": 0,
            "title": "Exceptions by Type (Last 24 Hours)"
          }
        },
        {
          "type": 3,
          "content": {
            "version": "KqlItem/1.0",
            "query": "dependencies\\n| where timestamp > ago(1h)\\n| summarize avg(duration) by target\\n| render barchart",
            "size": 0,
            "title": "Dependency Response Times (Last Hour)"
          }
        }
      ]
    }
    ''')
    category: 'workbook'
    sourceId: applicationInsights.id
  }
  tags: {
    Environment: environmentName
    Project: 'FarmersBank'
  }
}

// Outputs
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.id
output applicationInsightsId string = applicationInsights.id
output applicationInsightsInstrumentationKey string = applicationInsights.properties.InstrumentationKey
output applicationInsightsConnectionString string = applicationInsights.properties.ConnectionString
output actionGroupId string = actionGroup.id