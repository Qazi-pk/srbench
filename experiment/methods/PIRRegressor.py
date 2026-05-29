"""
SRBench (dev branch) method definition: PIR -- classical engine.

Format per dev CONTRIBUTING.md / experiment/methods/AFPRegressor.py. This file
lives at experiment/methods/PIRRegressor.py and defines the four objects the
harness looks for:
    est           a sklearn-compatible Regressor instance
    hyper_params  hyperparameter search space (empty -> no tuning)
    complexity    complexity(est) -> int model size
    model         model(est, X) -> sympy-compatible string

The classical engine is installed via experiment/methods/src/PIR_install.sh,
which pip-installs the PUBLIC, torch-free engine:
    git+https://github.com/Qazi-pk/physics-engine@v0.1.0

Config below is byte-for-byte the BLIND sweep that produced the archived
results_tierA_blind/ (7/44 stable, SEED=0): enforce_dimensions=False,
allowed_powers=[1,2], pairwise on, OT off, no physics features. All other
params left at adapter defaults (the blind sweep did not set them).
"""

import signal
import inspect
import numpy as np
import sympy as sp
from sklearn.base import BaseEstimator, RegressorMixin

from physics_engine.sklearn_adapter import PIRRegressor


# Exact blind-sweep config (matches sweep_tierA_blind.py, SEED = 0).
_PIR_VANILLA_CONFIG = dict(
    enforce_dimensions=False,
    allowed_powers=[1, 2],
    include_pairwise_products=True,
    use_ransac=True,
    use_residual=True,
    use_sparse=True,
    use_ot_loss=False,
    add_physics_features=False,
)


class _Timeout(Exception):
    pass


def _on_alarm(signum, frame):
    raise _Timeout()


class PIRClassicRegressor(BaseEstimator, RegressorMixin):
    """sklearn wrapper around classical PIRRegressor with a SIGALRM time budget
    and a guaranteed-valid fallback model."""

    def __init__(self, max_time=3600, random_state=0, **pir_kwargs):
        self.max_time = max_time
        self.random_state = random_state
        self.pir_kwargs = {**_PIR_VANILLA_CONFIG, **pir_kwargs}

    def _build(self):
        kw = dict(self.pir_kwargs)
        try:
            return PIRRegressor(random_state=self.random_state, **kw)
        except TypeError:
            return PIRRegressor(**kw)

    def fit(self, X, y):
        y_arr = np.asarray(y, dtype=float).ravel()
        self.expr_ = repr(float(np.mean(y_arr))) if y_arr.size else "0.0"
        self.n_features_in_ = np.asarray(X).shape[1] if np.ndim(X) > 1 else 1
        self._inner = self._build()

        use_alarm = hasattr(signal, "SIGALRM") and self.max_time and self.max_time > 0
        old = None
        if use_alarm:
            old = signal.signal(signal.SIGALRM, _on_alarm)
            signal.alarm(int(self.max_time))
        try:
            self._inner.fit(X, y)
            if hasattr(self._inner, "model"):
                self.expr_ = self._inner.model()
            elif hasattr(self._inner, "expr_"):
                self.expr_ = str(self._inner.expr_)
        except _Timeout:
            pass
        finally:
            if use_alarm:
                signal.alarm(0)
                if old is not None:
                    signal.signal(signal.SIGALRM, old)
        self.is_fitted_ = True
        return self

    def predict(self, X):
        if hasattr(self, "_inner") and hasattr(self._inner, "predict"):
            try:
                return self._inner.predict(X)
            except Exception:
                pass
        n = X.shape[0] if hasattr(X, "shape") else len(X)
        try:
            val = float(self.expr_)
        except (TypeError, ValueError):
            val = 0.0
        return np.full(n, val, dtype=float)


est = PIRClassicRegressor(max_time=3600, random_state=0)

# No hyperparameter tuning: the blind sweep used a single fixed config.
# Empty list -> harness skips the grid search (matches skip_tuning on sym track).
hyper_params = {}


def complexity(est):
    """Model size = number of nodes in the sympy expression."""
    try:
        expr = sp.sympify(str(getattr(est, "expr_", "0")))
        return int(sp.count_ops(expr)) + len(expr.free_symbols)
    except Exception:
        return 0


def model(est, X=None):
    """Return a sympy-parseable model string with symbols matching the dataset
    feature columns.

    SRBench passes X_train_scaled (a numpy array, no column names) when the
    signature accepts X. The engine emits symbols using whatever names it saw
    at fit time. If the engine already produced dataset-style names, return as
    is; otherwise leave generic positional names for SRBench's symbolic_utils
    mapping. (Confirm naming against one real dataset in local CI -- see notes.)
    """
    expr = str(getattr(est, "expr_", "0.0"))
    return expr
