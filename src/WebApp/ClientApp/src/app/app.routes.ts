import { Routes } from '@angular/router';
import { ProductListComponent } from './products/product-list.component';

export const routes: Routes = [
  { path: '', redirectTo: 'products', pathMatch: 'full' },
  { path: 'products', component: ProductListComponent },
];
