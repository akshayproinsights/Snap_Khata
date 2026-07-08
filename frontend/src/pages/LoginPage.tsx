import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useAuth } from '../contexts/AuthContext';
import { MessageCircle, Lock, Shield, CheckCircle, Eye, EyeOff, KeyRound, X } from 'lucide-react';
import { authAPI } from '../services/api';

/* ─────────────────────────────────────────────────────────────
   Change-Password Modal
───────────────────────────────────────────────────────────── */
const ChangePasswordModal: React.FC<{ onClose: () => void }> = ({ onClose }) => {
    const [username, setUsername] = useState('');
    const [currentPassword, setCurrentPassword] = useState('');
    const [newPassword, setNewPassword] = useState('');
    const [confirmPassword, setConfirmPassword] = useState('');
    const [showCurrent, setShowCurrent] = useState(false);
    const [showNew, setShowNew] = useState(false);
    const [showConfirm, setShowConfirm] = useState(false);
    const [isLoading, setIsLoading] = useState(false);
    const [error, setError] = useState('');
    const [success, setSuccess] = useState('');

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setSuccess('');

        if (newPassword !== confirmPassword) {
            setError('New passwords do not match.');
            return;
        }
        if (newPassword.length < 6) {
            setError('New password must be at least 6 characters.');
            return;
        }
        if (newPassword === currentPassword) {
            setError('New password must be different from the current password.');
            return;
        }

        setIsLoading(true);
        try {
            const res = await authAPI.changePassword(username, currentPassword, newPassword);
            setSuccess(res.message || 'Password changed successfully! You can now log in with your new password.');
        } catch (err: any) {
            setError(err.response?.data?.detail || 'Failed to change password. Please try again.');
        } finally {
            setIsLoading(false);
        }
    };

    // Password strength indicator
    const getStrength = (pw: string) => {
        let score = 0;
        if (pw.length >= 8) score++;
        if (/[A-Z]/.test(pw)) score++;
        if (/[0-9]/.test(pw)) score++;
        if (/[^A-Za-z0-9]/.test(pw)) score++;
        return score;
    };
    const strength = getStrength(newPassword);
    const strengthLabels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
    const strengthColors = ['', '#ef4444', '#f97316', '#eab308', '#22c55e'];

    return (
        /* Backdrop */
        <div
            className="fixed inset-0 z-50 flex items-center justify-center p-4"
            style={{ backgroundColor: 'rgba(0,0,0,0.55)', backdropFilter: 'blur(4px)' }}
            onClick={(e) => { if (e.target === e.currentTarget) onClose(); }}
        >
            <div
                className="bg-white rounded-2xl shadow-2xl w-full max-w-md relative"
                style={{ animation: 'modalIn 0.22s cubic-bezier(0.34,1.56,0.64,1) both' }}
            >
                {/* Header */}
                <div className="flex items-center justify-between px-6 py-5 border-b border-gray-100">
                    <div className="flex items-center gap-3">
                        <div className="w-9 h-9 rounded-xl bg-blue-50 flex items-center justify-center">
                            <KeyRound className="w-5 h-5 text-blue-600" />
                        </div>
                        <div>
                            <h2 className="text-base font-bold text-gray-800">Change Password</h2>
                            <p className="text-xs text-gray-500">Update your account password</p>
                        </div>
                    </div>
                    <button
                        onClick={onClose}
                        className="w-8 h-8 rounded-lg flex items-center justify-center text-gray-400 hover:text-gray-600 hover:bg-gray-100 transition-all"
                        aria-label="Close"
                    >
                        <X className="w-4 h-4" />
                    </button>
                </div>

                {/* Body */}
                <form onSubmit={handleSubmit} className="px-6 py-5 space-y-4">
                    {/* Status messages */}
                    {error && (
                        <div className="bg-red-50 border-l-4 border-red-500 text-red-700 px-4 py-3 rounded-lg text-sm">
                            <strong className="font-semibold">Error: </strong>{error}
                        </div>
                    )}
                    {success && (
                        <div className="bg-green-50 border-l-4 border-green-500 text-green-700 px-4 py-3 rounded-lg text-sm flex items-start gap-2">
                            <CheckCircle className="w-4 h-4 mt-0.5 shrink-0" />
                            <span>{success}</span>
                        </div>
                    )}

                    {!success && (
                        <>
                            {/* Username */}
                            <div>
                                <label className="block text-sm font-semibold text-gray-700 mb-1.5">User ID</label>
                                <input
                                    type="text"
                                    value={username}
                                    onChange={(e) => setUsername(e.target.value)}
                                    placeholder="Enter your User ID"
                                    className="w-full px-4 py-2.5 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all bg-gray-50 hover:bg-white text-sm"
                                    required
                                    autoComplete="username"
                                />
                            </div>

                            {/* Current password */}
                            <div>
                                <label className="block text-sm font-semibold text-gray-700 mb-1.5">Current Password</label>
                                <div className="relative">
                                    <input
                                        type={showCurrent ? 'text' : 'password'}
                                        value={currentPassword}
                                        onChange={(e) => setCurrentPassword(e.target.value)}
                                        placeholder="Enter current password"
                                        className="w-full px-4 py-2.5 pr-10 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all bg-gray-50 hover:bg-white text-sm"
                                        required
                                        autoComplete="current-password"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowCurrent((v) => !v)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                                        tabIndex={-1}
                                    >
                                        {showCurrent ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                                    </button>
                                </div>
                            </div>

                            {/* New password */}
                            <div>
                                <label className="block text-sm font-semibold text-gray-700 mb-1.5">New Password</label>
                                <div className="relative">
                                    <input
                                        type={showNew ? 'text' : 'password'}
                                        value={newPassword}
                                        onChange={(e) => setNewPassword(e.target.value)}
                                        placeholder="Enter new password"
                                        className="w-full px-4 py-2.5 pr-10 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all bg-gray-50 hover:bg-white text-sm"
                                        required
                                        autoComplete="new-password"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowNew((v) => !v)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                                        tabIndex={-1}
                                    >
                                        {showNew ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                                    </button>
                                </div>
                                {/* Strength bar */}
                                {newPassword && (
                                    <div className="mt-2">
                                        <div className="flex gap-1">
                                            {[1, 2, 3, 4].map((lvl) => (
                                                <div
                                                    key={lvl}
                                                    className="flex-1 h-1 rounded-full transition-all duration-300"
                                                    style={{ backgroundColor: lvl <= strength ? strengthColors[strength] : '#e5e7eb' }}
                                                />
                                            ))}
                                        </div>
                                        <p className="text-xs mt-1" style={{ color: strengthColors[strength] || '#9ca3af' }}>
                                            {newPassword ? strengthLabels[strength] || 'Very Weak' : ''}
                                        </p>
                                    </div>
                                )}
                            </div>

                            {/* Confirm new password */}
                            <div>
                                <label className="block text-sm font-semibold text-gray-700 mb-1.5">Confirm New Password</label>
                                <div className="relative">
                                    <input
                                        type={showConfirm ? 'text' : 'password'}
                                        value={confirmPassword}
                                        onChange={(e) => setConfirmPassword(e.target.value)}
                                        placeholder="Re-enter new password"
                                        className={`w-full px-4 py-2.5 pr-10 border-2 rounded-xl focus:ring-2 outline-none transition-all bg-gray-50 hover:bg-white text-sm ${
                                            confirmPassword && confirmPassword !== newPassword
                                                ? 'border-red-400 focus:ring-red-400 focus:border-red-400'
                                                : 'border-gray-200 focus:ring-blue-500 focus:border-blue-500'
                                        }`}
                                        required
                                        autoComplete="new-password"
                                    />
                                    <button
                                        type="button"
                                        onClick={() => setShowConfirm((v) => !v)}
                                        className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600"
                                        tabIndex={-1}
                                    >
                                        {showConfirm ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                                    </button>
                                </div>
                                {confirmPassword && confirmPassword !== newPassword && (
                                    <p className="text-xs text-red-500 mt-1">Passwords do not match</p>
                                )}
                            </div>
                        </>
                    )}

                    {/* Actions */}
                    <div className="flex gap-3 pt-1">
                        {success ? (
                            <button
                                type="button"
                                onClick={onClose}
                                className="flex-1 bg-green-600 hover:bg-green-700 text-white font-semibold py-2.5 px-4 rounded-xl transition-all text-sm"
                            >
                                Done — Go to Login
                            </button>
                        ) : (
                            <>
                                <button
                                    type="button"
                                    onClick={onClose}
                                    className="flex-1 border-2 border-gray-200 text-gray-600 font-semibold py-2.5 px-4 rounded-xl hover:bg-gray-50 transition-all text-sm"
                                >
                                    Cancel
                                </button>
                                <button
                                    type="submit"
                                    disabled={isLoading}
                                    className="flex-1 bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white font-semibold py-2.5 px-4 rounded-xl transition-all text-sm disabled:opacity-50 disabled:cursor-not-allowed shadow-md hover:shadow-lg"
                                >
                                    {isLoading ? (
                                        <span className="flex items-center justify-center gap-2">
                                            <svg className="animate-spin h-4 w-4" viewBox="0 0 24 24">
                                                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                                                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                            </svg>
                                            Updating...
                                        </span>
                                    ) : 'Update Password'}
                                </button>
                            </>
                        )}
                    </div>
                </form>
            </div>
        </div>
    );
};

/* ─────────────────────────────────────────────────────────────
   Login Page
───────────────────────────────────────────────────────────── */
const LoginPage: React.FC = () => {
    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [showPassword, setShowPassword] = useState(false);
    const [error, setError] = useState('');
    const [isLoading, setIsLoading] = useState(false);
    const [showChangePassword, setShowChangePassword] = useState(false);
    const { login } = useAuth();
    const navigate = useNavigate();

    const handleSubmit = async (e: React.FormEvent) => {
        e.preventDefault();
        setError('');
        setIsLoading(true);

        try {
            await login(username, password);
            navigate('/');
        } catch (err: any) {
            setError(err.response?.data?.detail || 'Login failed. Please check your credentials.');
        } finally {
            setIsLoading(false);
        }
    };

    return (
        <>
            {/* Modal */}
            {showChangePassword && (
                <ChangePasswordModal onClose={() => setShowChangePassword(false)} />
            )}

            <style>{`
                @keyframes modalIn {
                    from { opacity: 0; transform: scale(0.92) translateY(10px); }
                    to   { opacity: 1; transform: scale(1) translateY(0); }
                }
            `}</style>

            <div className="min-h-screen flex">
                {/* Left Panel */}
                <div className="hidden md:flex md:w-1/2 lg:w-3/5 bg-[#3B82F6] p-8 lg:p-12 flex-col justify-start items-center relative overflow-hidden">
                    <div className="relative z-10 w-full max-w-3xl mt-12">
                        <img
                            src="/login-panel.png"
                            alt="SnapKhata - Simply upload bills, we do the rest"
                            className="w-full h-auto object-contain"
                        />
                    </div>
                </div>

                {/* Right Panel - Login Form */}
                <div className="flex-1 md:w-1/2 lg:w-2/5 bg-gradient-to-br from-gray-50 to-white flex items-center justify-center p-6 md:p-12">
                    <div className="w-full max-w-md">
                        {/* Logo & Brand */}
                        <div className="text-center mb-8">
                            <div className="flex items-center justify-center mb-4">
                                <img
                                    src="/snapkhata-logo-full.png"
                                    alt="SnapKhata - Scan Bill, Send on WhatsApp, Track & Settle"
                                    className="w-[280px] h-auto object-contain"
                                />
                            </div>

                            {/* Top 1% SMB SaaS Badge */}
                            <div className="inline-flex items-center gap-2 bg-gradient-to-r from-amber-50 to-yellow-50 border border-amber-200 rounded-full px-4 py-1.5 mb-4">
                                <span className="text-amber-500">🏆</span>
                                <span className="text-xs font-semibold text-amber-800">Top 1% SaaS for SMBs</span>
                            </div>

                            {/* Trust Badge */}
                            <div className="flex items-center justify-center gap-4 text-xs text-gray-600">
                                <div className="flex items-center gap-1">
                                    <Shield className="w-4 h-4 text-green-600" />
                                    <span className="font-medium">100% Secure</span>
                                </div>
                                <div className="w-1 h-1 bg-gray-300 rounded-full" />
                                <div className="flex items-center gap-1">
                                    <span className="font-semibold">🇮🇳 Made in India</span>
                                </div>
                            </div>
                        </div>

                        {/* Login Card */}
                        <div className="bg-white rounded-2xl shadow-2xl p-8 border border-gray-100">
                            <h2 className="text-xl font-bold text-gray-800 mb-6 text-center">
                                Login to Your Account
                            </h2>

                            <form onSubmit={handleSubmit} className="space-y-5">
                                {error && (
                                    <div className="bg-red-50 border-l-4 border-red-500 text-red-700 px-4 py-3 rounded-lg text-sm">
                                        <strong className="font-semibold">Error: </strong>{error}
                                    </div>
                                )}

                                <div>
                                    <label htmlFor="username" className="block text-sm font-semibold text-gray-700 mb-2">
                                        User ID
                                    </label>
                                    <input
                                        id="username"
                                        type="text"
                                        value={username}
                                        onChange={(e) => setUsername(e.target.value)}
                                        placeholder="Enter your User ID"
                                        className="w-full px-4 py-3 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all bg-gray-50 hover:bg-white text-base"
                                        required
                                        autoComplete="username"
                                    />
                                </div>

                                <div>
                                    <label htmlFor="password" className="block text-sm font-semibold text-gray-700 mb-2">
                                        Password
                                    </label>
                                    <div className="relative">
                                        <input
                                            id="password"
                                            type={showPassword ? 'text' : 'password'}
                                            value={password}
                                            onChange={(e) => setPassword(e.target.value)}
                                            placeholder="Enter your password"
                                            className="w-full px-4 py-3 pr-12 border-2 border-gray-200 rounded-xl focus:ring-2 focus:ring-blue-500 focus:border-blue-500 outline-none transition-all bg-gray-50 hover:bg-white text-base"
                                            required
                                            autoComplete="current-password"
                                        />
                                        <button
                                            type="button"
                                            onClick={() => setShowPassword((v) => !v)}
                                            className="absolute right-4 top-1/2 -translate-y-1/2 text-gray-400 hover:text-gray-600 transition-colors"
                                            tabIndex={-1}
                                            aria-label={showPassword ? 'Hide password' : 'Show password'}
                                        >
                                            {showPassword ? <EyeOff className="w-5 h-5" /> : <Eye className="w-5 h-5" />}
                                        </button>
                                    </div>

                                    {/* Change password link — below the password field */}
                                    <div className="flex justify-end mt-1.5">
                                        <button
                                            type="button"
                                            onClick={() => setShowChangePassword(true)}
                                            className="text-xs text-blue-600 hover:text-blue-700 font-medium hover:underline transition-all"
                                        >
                                            Change Password?
                                        </button>
                                    </div>
                                </div>

                                <button
                                    type="submit"
                                    disabled={isLoading}
                                    className="w-full bg-gradient-to-r from-blue-600 to-blue-700 hover:from-blue-700 hover:to-blue-800 text-white font-semibold py-3.5 px-4 rounded-xl transition-all duration-200 disabled:opacity-50 disabled:cursor-not-allowed shadow-lg hover:shadow-xl transform hover:-translate-y-0.5"
                                >
                                    {isLoading ? (
                                        <span className="flex items-center justify-center gap-2">
                                            <svg className="animate-spin h-5 w-5" viewBox="0 0 24 24">
                                                <circle className="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" strokeWidth="4" fill="none" />
                                                <path className="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z" />
                                            </svg>
                                            Signing in...
                                        </span>
                                    ) : 'Login'}
                                </button>

                                {/* WhatsApp Alert Info */}
                                <div className="bg-green-50 border border-green-200 rounded-lg p-3 flex items-start gap-2">
                                    <MessageCircle className="w-5 h-5 text-green-600 mt-0.5 flex-shrink-0" />
                                    <div className="text-sm">
                                        <p className="font-semibold text-green-800">Get Daily WhatsApp Reports</p>
                                        <p className="text-green-700 text-xs mt-1">Income, expenses & stock alerts on WhatsApp</p>
                                    </div>
                                </div>

                                <div className="text-center pt-2">
                                    <span className="text-gray-600 text-sm">No account? </span>
                                    <a href="#" className="text-blue-600 hover:text-blue-700 font-semibold hover:underline transition-all text-sm">
                                        Sign up free
                                    </a>
                                </div>
                            </form>
                        </div>

                        {/* Trust Indicators */}
                        <div className="mt-6 space-y-3">
                            <div className="flex items-center justify-center gap-2 text-sm text-gray-600">
                                <Lock className="w-4 h-4 text-green-600" />
                                <span className="font-medium">Your data is safe & secure</span>
                            </div>

                            <div className="flex items-center justify-center gap-4 text-xs text-gray-500">
                                <div className="flex items-center gap-1">
                                    <CheckCircle className="w-3 h-3 text-blue-500" />
                                    <span>Owner-only access</span>
                                </div>
                                <div className="w-1 h-1 bg-gray-300 rounded-full" />
                                <div className="flex items-center gap-1">
                                    <CheckCircle className="w-3 h-3 text-blue-500" />
                                    <span>GST compliant</span>
                                </div>
                            </div>

                            <div className="text-center text-xs text-gray-500 pt-2">
                                Need help? <a href="#" className="text-blue-600 hover:underline font-medium">Contact support</a>
                            </div>
                        </div>
                    </div>
                </div>
            </div>
        </>
    );
};

export default LoginPage;
