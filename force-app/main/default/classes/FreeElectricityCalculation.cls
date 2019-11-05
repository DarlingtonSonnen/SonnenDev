/**
 * Created by b.jarmolinski on 24/04/2018.
 */

public with sharing class FreeElectricityCalculation {

    // calculates free electricity (freistrommenge) for sonnenFlat tariff
    private Decimal yearlyProduction; // actual yearly customer's electricity production
    private Decimal minProduction; // min yearly energy production for the tariff
    private Decimal maxFreeAllowance; // maximal free electricity for the given tariff
    private Decimal factor; // multiplier for calculation free electricity

    public FreeElectricityCalculation(Decimal yearlyProduction, Decimal minProduction, Decimal maxFreeAllowance, Decimal factor) {
        this.yearlyProduction = yearlyProduction;
        this.minProduction = minProduction;
        this.maxFreeAllowance = maxFreeAllowance;
        this.factor = factor;
    }

    public Decimal calculateAllowance() {

        System.debug('maxFreeAllowance '+maxFreeAllowance);
        System.debug('minProduction '+minProduction);
        System.debug('yearlyProduction '+yearlyProduction);

        Decimal freeElectricity;
        if (yearlyProduction > minProduction) {
            freeElectricity = maxFreeAllowance;
        } else {
            freeElectricity = (maxFreeAllowance - (minProduction - yearlyProduction)*factor).setScale(0);
        }
        return freeElectricity;
    }
}