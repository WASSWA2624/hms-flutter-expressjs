A good HMS dashboard should be **task-oriented**, not just report-oriented. Every user should immediately see:

1. **What requires my attention now?** (work queue)
2. **What's happening today?** (summary)
3. **What needs action?** (alerts)
4. **How am I performing?** (KPIs)

The dashboard should render each component only if the logged-in user has **all required permissions**.

---

# 1. System Administrator

`super.admin@hosspi.com`

Purpose: Manage the entire SaaS platform.

| Dashboard Component | Description                | Required Permission(s)                  |
| ------------------- | -------------------------- | --------------------------------------- |
| Platform Overview   | Tenants, facilities, users | `system:admin`                          |
| Active Tenants      | Total, suspended, trial    | `system:admin`                          |
| Subscription Status | Expiring subscriptions     | `subscriptions:read`                    |
| Platform Users      | Total users                | `system:admin`                          |
| System Health       | Services, queues, uptime   | `system:admin`                          |
| Integration Status  | APIs, EMR integrations     | `integration:read`                      |
| Security Alerts     | Break-glass requests       | `compliance:read`, `break_glass:review` |
| Audit Summary       | Compliance events          | `compliance:read`                       |
| Reports             | Platform analytics         | `reports:read`                          |
| Recent Activities   | Latest platform actions    | `system:admin`                          |

---

# 2. Tenant Administrator

`tenant.admin@hosspi.com`

Purpose: Manage one healthcare organization.

| Component            | Permissions          |
| -------------------- | -------------------- |
| Facilities Summary   | `tenant:admin`       |
| Total Patients       | `patient:read`       |
| Today's Revenue      | `billing:read`       |
| Clinical Activity    | `clinical:read`      |
| HR Summary           | `hr:read`            |
| Roster Status        | `roster:read`        |
| Operations Summary   | `operations:read`    |
| Facility Performance | `reports:read`       |
| Subscription Status  | `subscriptions:read` |
| Compliance Alerts    | `compliance:read`    |

---

# 3. Facility Administrator

`facility.admin@hosspi.com`

Purpose: Manage one hospital.

| Component          | Permissions       |
| ------------------ | ----------------- |
| Today's Admissions | `patient:read`    |
| Waiting Patients   | `patient:read`    |
| Bed Occupancy      | `patient:read`    |
| Emergency Queue    | `emergency:read`  |
| Revenue Today      | `billing:read`    |
| Pharmacy Summary   | `pharmacy:read`   |
| Lab Summary        | `lab:read`        |
| HR Attendance      | `hr:read`         |
| Equipment Status   | `biomed:read`     |
| Operations Summary | `operations:read` |
| Reports            | `reports:read`    |

---

# 4. Doctor

`doctor@hosspi.com`

Purpose: Treat patients.

| Component                   | Permissions      |
| --------------------------- | ---------------- |
| My Patients Today           | `clinical:read`  |
| Today's Appointments        | `clinical:read`  |
| Patients Waiting            | `clinical:read`  |
| Critical Patients           | `clinical:read`  |
| Lab Results Awaiting Review | `lab:read`       |
| Radiology Results           | `radiology:read` |
| Prescriptions Pending       | `pharmacy:read`  |
| Recent Clinical Notes       | `clinical:read`  |
| Emergency Calls             | `emergency:read` |
| My Schedule                 | `roster:read`    |

---

# 5. Nurse

`nurse@hosspi.com`

| Component           | Permissions      |
| ------------------- | ---------------- |
| Assigned Patients   | `clinical:read`  |
| Medication Schedule | `pharmacy:read`  |
| Vital Signs Due     | `clinical:read`  |
| Nursing Tasks       | `clinical:read`  |
| Patient Transfers   | `patient:read`   |
| Emergency Alerts    | `emergency:read` |
| Lab Requests        | `lab:read`       |
| Shift Schedule      | `roster:read`    |

---

# 6. Laboratory

`lab@hosspi.com`

| Component         | Permissions  |
| ----------------- | ------------ |
| Pending           | `lab:read`   |
| Critical today    | `lab:read`   |
| Completed today   | `lab:read`   |
| All patients      | `lab:read`   |
| Equipment Alerts  | `biomed:read` |

---

# 7. Pharmacy

`pharmacy@hosspi.com`

| Component           | Permissions      |
| ------------------- | ---------------- |
| Prescriptions Queue | `pharmacy:read`  |
| Pending Dispensing  | `pharmacy:write` |
| Low Stock Medicines | `pharmacy:read`  |
| Expiring Medicines  | `pharmacy:read`  |
| Controlled Drugs    | `pharmacy:read`  |
| Dispensed Today     | `pharmacy:read`  |
| Billing Pending     | `billing:read`   |

---

# 8. Reception

`reception@hosspi.com`

| Component            | Permissions      |
| -------------------- | ---------------- |
| Today's Appointments | `patient:read`   |
| Walk-in Queue        | `patient:read`   |
| Waiting Patients     | `patient:read`   |
| New Registrations    | `patient:write`  |
| Admissions           | `patient:write`  |
| Pending Payments     | `billing:read`   |
| Emergency Arrivals   | `emergency:read` |

---

# 9. Billing

`billing@hosspi.com`

| Component                | Permissions         |
| ------------------------ | ------------------- |
| Today's Revenue          | `billing:read`      |
| Outstanding Bills        | `billing:read`      |
| Pending Insurance Claims | `billing:read`      |
| Pending Approvals        | `financial:approve` |
| Refund Requests          | `billing:write`     |
| Revenue Trend            | `reports:read`      |
| Billing Events           | `billing:read`      |

---

# 10. Operations

`operations@hosspi.com`

| Component             | Permissions       |
| --------------------- | ----------------- |
| Facility Status       | `operations:read` |
| Maintenance Requests  | `operations:read` |
| Security Incidents    | `operations:read` |
| Utilities Status      | `operations:read` |
| Open Tasks            | `operations:read` |
| Daily Operations KPIs | `reports:read`    |

---

# 11. Human Resources

`hr@hosspi.com`

| Component           | Permissions      |
| ------------------- | ---------------- |
| Staff on Duty       | `hr:read`        |
| Attendance Summary  | `hr:read`        |
| Vacant Positions    | `hr:read`        |
| Leave Requests      | `hr:read`        |
| Roster Status       | `roster:read`    |
| Roster Approvals    | `roster:approve` |
| Department Staffing | `unit:read`      |

---

# 12. Biomedical

`biomed@hosspi.com`

| Component                 | Permissions    |
| ------------------------- | -------------- |
| Equipment Due for Service | `biomed:read`  |
| Equipment Breakdown       | `biomed:read`  |
| Maintenance Schedule      | `biomed:read`  |
| Calibration Due           | `biomed:read`  |
| Work Orders               | `biomed:write` |
| Equipment by Department   | `biomed:read`  |

---

# 13. Housekeeping

`housekeeping@hosspi.com`

| Component                 | Permissions       |
| ------------------------- | ----------------- |
| Cleaning Tasks            | `operations:read` |
| Rooms Awaiting Cleaning   | `operations:read` |
| Isolation Rooms           | `operations:read` |
| Waste Collection Schedule | `operations:read` |
| Supplies Status           | `operations:read` |

---

# 14. Ambulance

`ambulance@hosspi.com`

| Component                  | Permissions       |
| -------------------------- | ----------------- |
| Active Ambulances          | `emergency:read`  |
| Dispatch Queue             | `emergency:read`  |
| Emergency Calls            | `emergency:read`  |
| Completed Trips Today      | `emergency:read`  |
| Vehicle Maintenance Alerts | `operations:read` |

---

# 15. Patient Portal

`patient.portal@hosspi.com`

| Component              | Permissions           |
| ---------------------- | --------------------- |
| Upcoming Appointments  | `patient:read`        |
| Medical History        | `clinical:read`       |
| Lab Results            | `lab:read`            |
| Radiology Reports      | `radiology:read`      |
| Prescriptions          | `pharmacy:read`       |
| Outstanding Bills      | `billing:read`        |
| Messages from Hospital | `communications:read` |
| Profile                | `profile:read`        |

---

# Recommended Common Dashboard Layout

For consistency across all roles, use the same visual structure:

```
--------------------------------------------------------
Header
--------------------------------------------------------
Greeting
Current Shift
Notifications
Quick Actions
--------------------------------------------------------

KPI Cards (4–6)
--------------------------------------------------------
Today's Patients
Revenue
Pending Tasks
Critical Alerts
...

--------------------------------------------------------
Main Work Queue (60%)
--------------------------------------------------------
Role-specific tasks

--------------------------------------------------------
Secondary Panel (40%)
--------------------------------------------------------
Calendar
Alerts
Recent Activity
Announcements

--------------------------------------------------------
Charts
--------------------------------------------------------
Daily Trend
Weekly Trend
Monthly Trend

--------------------------------------------------------
Recent Activities
--------------------------------------------------------
Latest actions by the user/team
```

## Permission Evaluation Strategy

Instead of assigning dashboards to roles directly, make each dashboard widget declare its own permission requirements. At runtime:

```text
if user.hasPermissions(widget.requiredPermissions)
    show widget
else
    hide widget
```

This makes the dashboard fully dynamic. For example, if a doctor is additionally granted `reports:read`, a "Clinical Performance" chart can automatically appear without creating a new role. Likewise, if a facility administrator loses `billing:read`, all revenue-related widgets disappear while the rest of the dashboard remains available. This permission-driven approach scales much better than maintaining separate dashboards for every role combination.
