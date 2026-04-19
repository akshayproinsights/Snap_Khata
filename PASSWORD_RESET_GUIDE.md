# Password Reset Guide

Quick guide to view users and reset passwords for SnapKhata.

---

## View All Users

```bash
cd /root/Snap_Khata/backend && source venv/bin/activate && python3 ../admin_user_tool.py --list
```

**Output:**
```
================================================================================
Username             R2 Bucket            Industry        Created
================================================================================
Aksh                 aksh-invoices        general         2026-03-31T10:23:49
Ak123                snapkhata-prod       general         2026-03-31T10:40:11
AkshayK              snapkhata-prod       grocery         2026-04-01T11:43:18

Total users: 3
```

---

## Check Specific User

```bash
cd /root/Snap_Khata/backend && source venv/bin/activate && python3 ../admin_user_tool.py --check USERNAME
```

Example:
```bash
python3 ../admin_user_tool.py --check AkshayK
```

**Output:**
```
✓ User 'AkshayK' EXISTS
  Has password: True
  R2 bucket: snapkhata-prod
```

---

## View User Details

```bash
cd /root/Snap_Khata/backend && source venv/bin/activate && python3 ../admin_user_tool.py --view USERNAME
```

Example:
```bash
python3 ../admin_user_tool.py --view AkshayK
```

**Output:**
```
============================================================
User: AkshayK
============================================================
  username            : AkshayK
  password_hash       : $2b$12$NDK/BM/3bGsIYRmOxv... [HASH - cannot be decrypted]
  r2_bucket           : snapkhata-prod
  created_at          : 2026-04-01T11:43:18.932837+00:00
  industry            : grocery
```

---

## Reset Password

```bash
cd /root/Snap_Khata/backend && source venv/bin/activate && python3 ../admin_user_tool.py --reset USERNAME --password NEW_PASSWORD
```

**Example - Reset AkshayK's password to "Akshay":**
```bash
python3 ../admin_user_tool.py --reset AkshayK --password Akshay
```

**Output:**
```
✓ Password reset for 'AkshayK'
  New password: Akshay
```

**Use a random password for security:**
```bash
python3 ../admin_user_tool.py --reset AkshayK --password Temp1234!
```

---

## Quick Reference

| Task | Command |
|------|---------|
| List users | `python3 ../admin_user_tool.py --list` |
| Check user | `python3 ../admin_user_tool.py --check USERNAME` |
| View details | `python3 ../admin_user_tool.py --view USERNAME` |
| Reset password | `python3 ../admin_user_tool.py --reset USERNAME --password NEWPASS` |

---

## Important Notes

1. **Passwords are NOT stored in plain text** - they are bcrypt hashed and cannot be decrypted
2. **Admin can only reset passwords** - never retrieve original passwords
3. **Always use the full path** - commands must be run from `backend/` folder with venv activated
4. **Tell user the new password** - they should change it after logging in

---

## Troubleshooting

**"User not found"**
- Check username spelling (case-sensitive)
- Run `--list` to see all usernames

**"Connection error"**
- Ensure backend venv is activated: `source venv/bin/activate`
- Check Supabase credentials in backend/.env

**Password reset not working**
- Check if user exists first with `--check`
- Verify new password meets any frontend requirements
