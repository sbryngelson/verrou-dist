/* Tiny smoke test: a catastrophic-cancellation accumulation whose result is
 * sensitive to rounding. Under Verrou random rounding the printed sum must
 * differ from the nearest-rounding value; that proves the verrou tool actually
 * perturbs FP operations (not just that the binary runs). */
#include <stdio.h>

int main(void) {
    double acc = 0.0;
    for (int i = 1; i <= 200000; i++) {
        acc += 1.0 / (double)i;          /* rounds every iteration */
    }
    printf("%.17g\n", acc);
    return 0;
}
